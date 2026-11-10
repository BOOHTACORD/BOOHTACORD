package runrostermatrix

import (
	"context"
	"time"

	"voice-platform/backend/internal/load/observe_resources"
)

func waitForSteady(ctx context.Context, actors []*Actor, measurements *Measurements, guard observe_resources.Guard, change bool, work func(context.Context) error) (string, string) {
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()
	var steady <-chan time.Time
	started := false
	for {
		if measurements.Complete() && !started {
			started = true
			if work != nil && work(ctx) != nil {
				return "FAIL", "message_workload"
			}
			if change {
				if measurements.StartMaintenanceChange(time.Now()) != nil || guard.ChangeMaintenance(ctx) != nil {
					return "FAIL", "maintenance_change_trigger"
				}
			}
		}
		if started && (!change || measurements.ChangeComplete()) && steady == nil {
			timer := time.NewTimer(10 * time.Second)
			defer timer.Stop()
			steady = timer.C
		}
		select {
		case <-ctx.Done():
			return "FAIL", "deadline_or_guard"
		case <-steady:
			if anyFailed(actors) {
				return "FAIL", "stream_failure"
			}
			if change {
				return "PASS", "bounded_initial_change_and_steady"
			}
			return "PASS", "bounded_initial_and_steady"
		case <-ticker.C:
			if anyFailed(actors) {
				return "FAIL", "stream_failure"
			}
		}
	}
}
