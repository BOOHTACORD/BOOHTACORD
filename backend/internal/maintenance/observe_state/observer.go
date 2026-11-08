// Package observestate reconciles the authoritative maintenance flag for local subscribers.
package observestate

import (
	"context"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
)

type Reader interface {
	Active(context.Context) (bool, error)
}

// Known must be checked before interpreting Active; an outage is not inactive.
type State struct {
	Generation    string
	Revision      uint64
	Known, Active bool
}

type Observer struct {
	reader            Reader
	interval, timeout time.Duration
	mu                sync.Mutex
	state             State
	hasState          bool
	closed            bool
	sequence          uint64
	subscribers       map[*Subscription]struct{}
	refresh           chan struct{}
	running           atomic.Bool
}

func New(reader Reader, interval, timeout time.Duration) *Observer {
	if interval <= 0 {
		interval = 5 * time.Second
	}
	if timeout <= 0 {
		timeout = 3 * time.Second
	}
	return &Observer{reader: reader, interval: interval, timeout: timeout,
		state: State{Generation: uuid.NewString()}, subscribers: make(map[*Subscription]struct{}), refresh: make(chan struct{}, 1)}
}

// Run must be owned by the process lifecycle. Concurrent calls after the first are ignored.
func (o *Observer) Run(ctx context.Context) {
	if !o.running.CompareAndSwap(false, true) {
		return
	}
	defer o.shutdown()
	ticker := time.NewTicker(o.interval)
	defer ticker.Stop()
	var nextRead time.Time
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		case <-o.refresh:
		}
		if delay := time.Until(nextRead); delay > 0 {
			timer := time.NewTimer(delay)
			select {
			case <-ctx.Done():
				timer.Stop()
				return
			case <-timer.C:
			}
		}
		if o.read(ctx) {
			nextRead = time.Now().Add(o.interval)
		}
	}
}

func (o *Observer) RequestRefresh() {
	select {
	case o.refresh <- struct{}{}:
	default:
	}
}

func (o *Observer) read(parent context.Context) bool {
	o.mu.Lock()
	if len(o.subscribers) == 0 {
		o.mu.Unlock()
		return false
	}
	o.sequence++
	sequence := o.sequence
	o.mu.Unlock()
	ctx, cancel := context.WithTimeout(parent, o.timeout)
	active, err := o.reader.Active(ctx)
	if ctx.Err() != nil {
		err = ctx.Err()
	}
	cancel()
	if parent.Err() != nil {
		return false
	}
	o.apply(sequence, active, err == nil)
	return true
}
