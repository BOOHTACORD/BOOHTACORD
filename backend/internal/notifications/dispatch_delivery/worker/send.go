package notificationworker

import (
	"context"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	observe "voice-platform/backend/internal/notifications/observe_delivery"
)

func (w *Worker) send(ctx context.Context, c Config) {
	ticker := time.NewTicker(250 * time.Millisecond)
	defer ticker.Stop()
	var circuitUntil time.Time
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			if now.Before(circuitUntil) {
				continue
			}
			job, found, err := c.Dispatch.Claim(ctx, now.UTC())
			c.Telemetry.Tick("send", err)
			if err != nil || !found {
				continue
			}
			message, ready, err := c.Dispatch.Begin(ctx, job, c.Scope, c.Box, now.UTC())
			c.Telemetry.Tick("send", err)
			if err != nil || !ready {
				continue
			}
			result := delivery.Result{Outcome: "permanent_failure", Reason: "configuration_error"}
			if transport := c.Transports[message.Transport]; transport != nil {
				call, cancel := context.WithTimeout(ctx, 5*time.Second)
				call, endSpan := observe.Attempt(call, message.Transport)
				result = transport.Send(call, message)
				endSpan(result.Outcome, result.Reason)
				cancel()
			}
			for i := range message.Secret {
				message.Secret[i] = 0
			}
			if result.Reason == "configuration_error" {
				circuitUntil = time.Now().Add(time.Minute)
				result.Outcome = "retry"
				result.RetryAfter = time.Minute
			}
			// Completion gets its own bounded context, including during normal shutdown.
			complete, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
			err = c.Dispatch.Complete(complete, job, result, time.Now().UTC())
			c.Telemetry.Tick("send", err)
			if err == nil && result.Outcome == "accepted_by_provider" {
				c.Telemetry.Delay("provider_accepted", job.DueAt, time.Now())
			}
			cancel()
		}
	}
}
