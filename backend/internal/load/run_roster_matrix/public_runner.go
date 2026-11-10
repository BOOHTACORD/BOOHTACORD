package runrostermatrix

import (
	"context"
	"time"

	"voice-platform/backend/internal/load/observe_resources"
	"voice-platform/backend/internal/load/validate_target"
)

type PublicReport struct {
	Outcome, StopReason, Mode, Media string
	Guests                           int
	Measurements                     map[string]Summary
	Resources                        []observe_resources.Snapshot
}

func RunPublic(parent context.Context, manifest validate_target.Manifest, mode string, guests int) (report PublicReport) {
	report = PublicReport{Outcome: "FAIL", StopReason: "preflight", Mode: mode, Media: "NOT_RUN", Guests: guests}
	if manifest.ValidateRosterMatrix() != nil || (mode != "candidate" && mode != "baseline") || guests < 1 || guests > 100 || manifest.MaxRequests < guests || manifest.MaxSeconds < 20 || manifest.MaxSeconds > 600 {
		return
	}
	ctx, cancel := context.WithTimeout(parent, time.Duration(manifest.MaxSeconds)*time.Second)
	defer cancel()
	guard := observe_resources.Guard{Manifest: manifest, Client: validate_target.Client()}
	initial, err := guard.Check(ctx)
	if err != nil || initial.MetricsStatus != "AVAILABLE" {
		report.StopReason = "guard_preflight"
		return
	}
	watch := &monitor{samples: []observe_resources.Snapshot{initial}}
	done := make(chan struct{})
	go func() { defer close(done); watch.run(ctx, cancel, guard) }()
	measurements := NewPublicMeasurements(guests, mode == "candidate")
	var actors []*Actor
	defer func() {
		cancel()
		for _, actor := range actors {
			actor.Close()
		}
		<-done
		var failed bool
		report.Resources, failed = watch.result()
		report.Measurements = measurements.Snapshot()
		if failed {
			report.Outcome, report.StopReason = "FAIL", "guard_stop"
		}
	}()
	for i := 0; i < guests; i++ {
		if anyFailed(actors) {
			report.StopReason = "stream_failure"
			return
		}
		actor, startErr := StartGuest(ctx, validate_target.ClientFrom(0), manifest.Origin, i, mode == "baseline", measurements)
		if startErr != nil {
			report.StopReason = "guest_start"
			return
		}
		actors = append(actors, actor)
	}
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()
	var steady <-chan time.Time
	for {
		if measurements.Complete() && steady == nil {
			timer := time.NewTimer(10 * time.Second)
			defer timer.Stop()
			steady = timer.C
		}
		select {
		case <-ctx.Done():
			report.StopReason = "deadline_or_guard"
			return
		case <-steady:
			if anyFailed(actors) {
				report.StopReason = "stream_failure"
				return
			}
			report.Outcome, report.StopReason = "PASS", "bounded_initial_and_steady"
			return
		case <-ticker.C:
			if anyFailed(actors) {
				report.StopReason = "stream_failure"
				return
			}
		}
	}
}
