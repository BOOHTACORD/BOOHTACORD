package preparerosterdelivery

import (
	"context"
	"errors"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
)

func (p *Pool) run(ctx context.Context, sub Subscription, token string, principal auth.Principal, checker Guard, out chan Delivery) {
	if sub == nil || checker == nil {
		publish(ctx, out, Delivery{Unavailable: true})
		return
	}
	var pending *coordinator.State
	for {
		var state coordinator.State
		if pending != nil {
			state, pending = *pending, nil
		} else {
			select {
			case <-ctx.Done():
				return
			case value, ok := <-sub.Events():
				if !ok {
					return
				}
				state = value
			}
		}
		if !sub.Current(state) {
			if !sub.RequestRefresh() {
				return
			}
			continue
		}
		if state.Unavailable {
			if !publish(ctx, out, Delivery{Unavailable: true}) {
				return
			}
			continue
		}
		err := p.check(ctx, checker, token, principal, state)
		if ctx.Err() != nil {
			return
		}
		if errors.Is(err, guard.ErrSession) {
			publish(ctx, out, Delivery{SessionInvalid: true})
			return
		}
		if errors.Is(err, guard.ErrStale) || !sub.Current(state) {
			if !sub.RequestRefresh() {
				return
			}
			continue
		}
		select {
		case newer, ok := <-sub.Events():
			if !ok {
				return
			}
			pending = &newer
			continue
		default:
		}
		if err != nil {
			if !publish(ctx, out, Delivery{Unavailable: true}) {
				return
			}
			continue
		}
		if !publish(ctx, out, Delivery{State: state}) {
			return
		}
	}
}

func (p *Pool) check(parent context.Context, checker Guard, token string, principal auth.Principal, state coordinator.State) error {
	ctx, cancel := context.WithTimeout(parent, p.timeout)
	defer cancel()
	select {
	case p.slots <- struct{}{}:
	case <-ctx.Done():
		return guard.ErrUnavailable
	}
	defer func() { <-p.slots }()
	err := checker.Check(ctx, token, principal, state.Roster)
	if ctx.Err() != nil {
		return guard.ErrUnavailable
	}
	return err
}

func publish(ctx context.Context, out chan Delivery, value Delivery) bool {
	select {
	case <-ctx.Done():
		return false
	default:
	}
	select {
	case <-out:
	default:
	}
	select {
	case <-ctx.Done():
		return false
	case out <- value:
		return true
	}
}
