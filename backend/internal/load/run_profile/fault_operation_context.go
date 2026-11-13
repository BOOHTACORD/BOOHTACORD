package run_profile

import (
	"context"
	"time"
)

func operationContext(ctx context.Context, profile, phase string, duration time.Duration) (context.Context, context.CancelFunc) {
	if profile == "faults" && phase != "recovery" && phase != "saturation_stop" {
		return context.WithTimeout(ctx, duration)
	}
	return context.WithCancel(ctx)
}
