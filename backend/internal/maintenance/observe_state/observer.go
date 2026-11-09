// Package observestate reconciles the authoritative maintenance flag for local subscribers.
package observestate

import (
	"context"
	"sync"
	"sync/atomic"
	"time"
)

// Coalesce concurrent initial reads while keeping reconnect latency bounded.
const minimumReadSpacing = 5 * time.Millisecond

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
	readObserver      func(bool)
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
	return NewWithReadObserver(reader, interval, timeout, nil)
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
			nextRead = time.Now().Add(minimumReadSpacing)
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
	if o.readObserver != nil {
		o.readObserver(err == nil)
	}
	o.apply(sequence, active, err == nil)
	return true
}
