package runrostermatrix

import (
	"context"
	"errors"
	"time"
)

func waitMessageWarmup(ctx context.Context, milliseconds int) error {
	if ctx == nil || milliseconds < 0 || milliseconds > 2000 {
		return errors.New("invalid warmup")
	}
	if milliseconds == 0 {
		return ctx.Err()
	}
	timer := time.NewTimer(time.Duration(milliseconds) * time.Millisecond)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timer.C:
		return nil
	}
}
