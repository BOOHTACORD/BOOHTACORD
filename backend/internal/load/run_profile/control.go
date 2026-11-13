package run_profile

import (
	"context"
	"time"
	"voice-platform/backend/internal/load/exercise_actor"
	"voice-platform/backend/internal/load/observe_resources"
	"voice-platform/backend/internal/load/record_results"
)

func validProfile(p string) bool {
	return p == "nat_auth" || p == "normal" || p == "reconnect" || p == "uploads" || p == "faults"
}
func (r *Runner) admit(ctx context.Context, target int) error {
	for len(r.actors) < target {
		a := exercise_actor.New(r.Manifest, len(r.actors), r.results, &r.budget)
		r.actors = append(r.actors, a)
		if err := a.Start(ctx); err != nil {
			return err
		}
	}
	return nil
}
func (r *Runner) monitor(ctx context.Context, g observe_resources.Guard, stop chan<- string, cancel context.CancelFunc) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s, err := g.Check(ctx)
			if err != nil {
				if ctx.Err() != nil {
					return
				}
				r.mu.Lock()
				r.guardFailure = observe_resources.Category(err)
				r.mu.Unlock()
				stop <- "guard_resource_stop"
				cancel()
				return
			}
			r.mu.Lock()
			if len(r.resources) < 7200 {
				r.resources = append(r.resources, s)
			}
			r.mu.Unlock()
		}
	}
}
func criteria(rows map[string]record_results.Summary) map[string]string {
	value := "NOT_RUN"
	if v, ok := rows["fanout"]; ok && v.Count > 0 {
		value = "PASS"
		if v.Errors > 0 || v.P95MS > 500 {
			value = "FAIL"
		}
	}
	return map[string]string{"message_ws_p95_500ms": value, "voice_join_p95_3s": "NOT_RUN", "stream_switch_p95_2s": "NOT_RUN", "voice_restore_p95_10s": "NOT_RUN", "100_connected_voice_20_per_channel": "NOT_RUN"}
}
