package runrostermatrix

import (
	"context"
	"testing"
	"time"
)

func TestWarmupIsBoundedAndCancellationAware(t *testing.T) {
	if waitMessageWarmup(context.Background(), -1) == nil || waitMessageWarmup(context.Background(), 2001) == nil {
		t.Fatal("unsafe warmup accepted")
	}
	if err := waitMessageWarmup(context.Background(), 0); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	start := time.Now()
	if waitMessageWarmup(ctx, 1000) == nil || time.Since(start) > 200*time.Millisecond {
		t.Fatal("warmup did not stop on cancellation")
	}
}
