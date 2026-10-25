package relayruntime

import (
	"context"
	"time"
	"voice-platform/backend/internal/app/lifecycle"
	control "voice-platform/backend/internal/pushrelay/control_queue"
)

func startMaintenance(parent context.Context, store control.Store) lifecycle.Stop {
	ctx, cancel := context.WithCancel(parent)
	done := make(chan struct{})
	go func() {
		defer close(done)
		ticker := time.NewTicker(time.Minute)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case now := <-ticker.C:
				_ = store.Cleanup(ctx, now.UTC())
			}
		}
	}()
	return func(end context.Context) error {
		cancel()
		select {
		case <-done:
			return nil
		case <-end.Done():
			return end.Err()
		}
	}
}
