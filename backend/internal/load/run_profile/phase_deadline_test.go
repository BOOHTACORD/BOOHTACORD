package run_profile

import (
	"context"
	"errors"
	"testing"
	"time"
	"voice-platform/backend/internal/load/observe_resources"
)

func TestPhaseDeadlineInterruptsCadencePause(t *testing.T) {
	r := Runner{Profile: "normal"}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	started := time.Now()
	phase, err := r.phase(ctx, observe_resources.Guard{}, "warmup", 20*time.Millisecond)
	if err != nil || phase.Errors != 0 || time.Since(started) >= 250*time.Millisecond {
		t.Fatalf("phase timer did not interrupt the cadence pause: seconds=%f errors=%d err=%v", phase.Seconds, phase.Errors, err)
	}
}

func TestPhaseParentCancellationStillFails(t *testing.T) {
	r := Runner{Profile: "normal"}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	_, err := r.phase(ctx, observe_resources.Guard{}, "warmup", time.Second)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("parent cancellation must remain a failure: %v", err)
	}
}
