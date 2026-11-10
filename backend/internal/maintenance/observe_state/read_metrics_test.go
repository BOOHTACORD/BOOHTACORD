package observestate

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestReadReportsFixedOutcomeWithoutErrorDetails(t *testing.T) {
	outcomes := make(chan bool, 2)
	reader := readerFunc(func(context.Context) (bool, error) {
		return false, errors.New("private detail")
	})
	o := NewWithReadObserver(reader, time.Hour, time.Second, func(ok bool) { outcomes <- ok })
	sub := o.Subscribe()
	defer sub.Close()
	if !o.read(context.Background()) || <-outcomes {
		t.Fatal("failed read must report only a false outcome")
	}
}

func TestIdleAndShutdownDoNotReportReadFailures(t *testing.T) {
	outcomes := make(chan bool, 2)
	o := NewWithReadObserver(readerFunc(func(context.Context) (bool, error) {
		return false, nil
	}), time.Hour, time.Second, func(ok bool) { outcomes <- ok })
	if o.read(context.Background()) {
		t.Fatal("idle observer read unexpectedly")
	}
	sub := o.Subscribe()
	defer sub.Close()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if o.read(ctx) {
		t.Fatal("shutdown read unexpectedly reported completion")
	}
	select {
	case <-outcomes:
		t.Fatal("idle or canceled read emitted an outcome")
	default:
	}
}
