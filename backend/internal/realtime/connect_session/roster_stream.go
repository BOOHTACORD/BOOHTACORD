package connectsession

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

type RosterDelivery = prepared.Delivery

type RosterStream interface {
	Events() <-chan RosterDelivery
	Current(coordinator.State) bool
	RequestRefresh() bool
	Check(context.Context, coordinator.State) error
	WithRoster(context.Context, coordinator.State, func(context.Context) error) error
	Close()
}
type RosterFactory func(context.Context, auth.Principal, *http.Cookie) (RosterStream, error)

func closeRoster(stream RosterStream) {
	if stream != nil {
		stream.Close()
	}
}

func subscribeRoster(request *http.Request, principal auth.Principal, cookie *http.Cookie, factory RosterFactory) (RosterStream, error) {
	for _, capability := range requestedCapabilities(request) {
		if capability == "voice_roster_v1" {
			if factory == nil || cookie == nil {
				return nil, errors.New("roster unavailable")
			}
			stream, err := factory(request.Context(), principal, cookie)
			if err != nil || stream == nil {
				return nil, errors.New("roster unavailable")
			}
			return stream, nil
		}
	}
	return nil, nil
}

func writeRoster(connection *websocket.Conn, sub RosterStream, delivery RosterDelivery, maxBytes int, newID Identifier, now Clock) bool {
	if delivery.SessionInvalid {
		_ = connection.Close(websocket.StatusPolicyViolation, "session is no longer valid")
		return false
	}
	if !delivery.Unavailable && !sub.Current(delivery.State) {
		return sub.RequestRefresh()
	}
	if maxBytes <= 0 {
		maxBytes = 1 << 20
	}
	state := delivery.State
	payload := map[string]any{"version": 1, "generation": state.Generation, "revision": state.Revision, "observed_at": state.ObservedAt.UTC(), "channels": state.Roster.Channels}
	kind := "voice.roster.snapshot"
	if delivery.Unavailable || state.Revision == 0 || state.Revision > 9007199254740991 || state.ObservedAt.IsZero() || state.Roster.Channels == nil {
		kind, payload = unavailableRoster()
	} else if _, err := uuid.Parse(state.Generation); err != nil {
		kind, payload = unavailableRoster()
	}
	frame, err := json.Marshal(Event{EventID: newID(), Kind: kind, OccurredAt: now().UTC(), Payload: payload})
	if err != nil || len(frame) > maxBytes {
		kind, payload = unavailableRoster()
		frame, err = json.Marshal(Event{EventID: newID(), Kind: kind, OccurredAt: now().UTC(), Payload: payload})
	}
	if err != nil || len(frame) > maxBytes {
		return false
	}
	if kind == "voice.roster.snapshot" && !sub.Current(state) {
		return sub.RequestRefresh()
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if kind != "voice.roster.snapshot" {
		started := time.Now()
		err := connection.Write(ctx, websocket.MessageText, frame)
		if observer, ok := sub.(interface{ ObserveRosterUnavailable(time.Duration, bool) }); ok {
			observer.ObserveRosterUnavailable(time.Since(started), err == nil)
		}
		return err == nil
	}
	err = sub.WithRoster(ctx, state, func(writeCtx context.Context) error {
		if !sub.Current(state) {
			return guard.ErrStale
		}
		return connection.Write(writeCtx, websocket.MessageText, frame)
	})
	if errors.Is(err, guard.ErrSession) {
		_ = connection.Close(websocket.StatusPolicyViolation, "session is no longer valid")
		return false
	}
	if errors.Is(err, guard.ErrStale) {
		return sub.RequestRefresh()
	}
	if errors.Is(err, guard.ErrUnavailable) {
		return writeRoster(connection, sub, RosterDelivery{Unavailable: true}, maxBytes, newID, now)
	}
	return err == nil
}

func unavailableRoster() (string, map[string]any) {
	return "voice.roster.unavailable", map[string]any{"version": 1, "code": "temporarily_unavailable"}
}
