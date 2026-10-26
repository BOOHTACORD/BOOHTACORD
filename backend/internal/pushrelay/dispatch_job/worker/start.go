package relayworker

import (
	"context"
	"sync"
	"sync/atomic"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	dispatch "voice-platform/backend/internal/pushrelay/dispatch_job"
	provider "voice-platform/backend/internal/pushrelay/fcm_provider"
)

type Sender interface {
	Send(context.Context, provider.Message) delivery.Result
}
type Worker struct {
	cancel  context.CancelFunc
	done    chan struct{}
	circuit atomic.Int64
}

func Start(parent context.Context, store dispatch.Store, sender Sender) *Worker {
	ctx, cancel := context.WithCancel(parent)
	w := &Worker{cancel: cancel, done: make(chan struct{})}
	var group sync.WaitGroup
	for i := 0; i < 2; i++ {
		group.Add(1)
		go func() { defer group.Done(); w.run(ctx, store, sender) }()
	}
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
func (w *Worker) run(ctx context.Context, store dispatch.Store, sender Sender) {
	ticker := time.NewTicker(250 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			if now.UnixNano() < w.circuit.Load() {
				continue
			}
			work, ready, err := store.Next(ctx, now.UTC())
			if err != nil || !ready {
				continue
			}
			result := delivery.Result{Outcome: "retry", Reason: "configuration_error", RetryAfter: time.Minute}
			if sender != nil {
				call, cancel := context.WithTimeout(ctx, 5*time.Second)
				result = sender.Send(call, work.Message)
				cancel()
			}
			for i := range work.Message.Payload {
				work.Message.Payload[i] = 0
			}
			work.Message.Target = ""
			if result.Reason == "configuration_error" {
				w.circuit.Store(time.Now().Add(time.Minute).UnixNano())
				result.Outcome = "retry"
				result.RetryAfter = time.Minute
			}
			complete, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
			_ = store.Complete(complete, work.Job, result, time.Now().UTC())
			cancel()
		}
	}
}
