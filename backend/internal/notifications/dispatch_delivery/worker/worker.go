package notificationworker

import (
	"context"
	"sync"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	observe "voice-platform/backend/internal/notifications/observe_delivery"
	plan "voice-platform/backend/internal/notifications/plan_delivery"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	"voice-platform/backend/internal/notifications/secretbox"
)

type Worker struct {
	cancel context.CancelFunc
	done   chan struct{}
}
type Config struct {
	Telemetry   *observe.Runtime
	Planner     plan.Store
	Dispatch    delivery.Store
	Scope       reader.Scope
	Box         *secretbox.Box
	Transports  map[string]delivery.Transport
	Maintenance func(context.Context, time.Time) error
	Hints       func(context.Context, time.Time) error
}

func Start(parent context.Context, c Config) *Worker {
	ctx, cancel := context.WithCancel(parent)
	w := &Worker{cancel, make(chan struct{})}
	var group sync.WaitGroup
	// One planner and one sender: fixed concurrency regardless of guild size.
	group.Add(2)
	go func() { defer group.Done(); w.plan(ctx, c) }()
	go func() { defer group.Done(); w.send(ctx, c) }()
	go func() { group.Wait(); close(w.done) }()
	return w
}
func (w *Worker) Stop(ctx context.Context) error {
	w.cancel()
	select {
	case <-w.done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}
func (w *Worker) plan(ctx context.Context, c Config) {
	ticker := time.NewTicker(250 * time.Millisecond)
	defer ticker.Stop()
	maintenance := time.Now()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			for i := 0; i < 8; i++ {
				in, found, err := c.Planner.Claim(ctx, now.UTC())
				c.Telemetry.Tick("plan", err)
				if err != nil || !found {
					break
				}
				if _, err = c.Planner.Page(ctx, in, c.Scope, now.UTC()); err != nil {
					c.Telemetry.Tick("plan", err)
					break
				}
				c.Telemetry.Delay("eligible", in.DueAt, now)
			}
			if c.Hints != nil {
				_ = c.Hints(ctx, now.UTC())
			}
			if now.Sub(maintenance) >= time.Minute && c.Maintenance != nil {
				_ = c.Maintenance(ctx, now.UTC())
				maintenance = now
			}
		}
	}
}
