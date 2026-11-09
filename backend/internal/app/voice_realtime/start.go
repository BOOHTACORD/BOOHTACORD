package voicerealtime

import (
	"context"
	"time"

	"voice-platform/backend/internal/app/lifecycle"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
	watch "voice-platform/backend/internal/voice/watch_connected_participants"
)

// Start owns one coordinator and one notification subscription for the process.
func Start(parent context.Context, config coordinator.Config, lister coordinator.Lister, guard prepared.Guard, notifier *watch.Notifier, observers ...Observer) (*Factory, lifecycle.Stop, error) {
	if parent == nil || parent.Err() != nil || guard == nil || notifier == nil {
		return nil, nil, errUnavailable
	}
	changes, unsubscribe := notifier.Subscribe()
	var observer Observer
	if len(observers) > 0 {
		observer = observers[0]
	}
	c, err := coordinator.New(config, lister, changes, observer)
	if err != nil {
		unsubscribe()
		return nil, nil, err
	}
	pool, err := prepared.New(16, 2*time.Second)
	if err != nil {
		unsubscribe()
		return nil, nil, err
	}
	ctx, cancel := context.WithCancel(parent)
	done := make(chan struct{})
	go func() { defer close(done); defer unsubscribe(); c.Run(ctx) }()
	stop := func(ctx context.Context) error {
		cancel()
		select {
		case <-done:
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	return New(c, pool, guard, observer), stop, nil
}
