package run_profile

import (
	"context"
	"errors"
	"time"
	"voice-platform/backend/internal/load/observe_resources"
)

func (r *Runner) measuredPhase(ctx context.Context, guard observe_resources.Guard, name string, duration time.Duration) (Phase, error) {
	phase, err := r.phase(ctx, guard, name, duration)
	if err == nil && phase.Requests == 0 {
		phase.Failure = "no_workload"
		return phase, errors.New("measured phase had no workload")
	}
	return phase, err
}
