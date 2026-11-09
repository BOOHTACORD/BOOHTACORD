// Package publicrealtime owns the public transport's process lifecycle.
package publicrealtime

import (
	"context"
	"errors"
	"net/http"
	"time"

	"voice-platform/backend/internal/app/lifecycle"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	admitpublic "voice-platform/backend/internal/realtime/admit_public_connection"
	connectpublic "voice-platform/backend/internal/realtime/connect_public"
	ratelimit "voice-platform/backend/internal/security/rate_limit"
)

func Start(parent context.Context, reader observestate.Reader, origin string, trusted []string) (http.Handler, lifecycle.Stop, error) {
	handler, _, stop, err := StartShared(parent, reader, origin, trusted)
	return handler, stop, err
}

// StartShared supplies the same process-owned observer to the authenticated route.
func StartShared(parent context.Context, reader observestate.Reader, origin string, trusted []string, metrics ...connectpublic.ConnectionObserver) (http.Handler, *observestate.Observer, lifecycle.Stop, error) {
	if reader == nil {
		return nil, nil, nil, errors.New("missing maintenance reader")
	}
	rate, err := ratelimit.New(ratelimit.Config{Limit: 240, Window: time.Minute, MaxSources: 10_000, TrustedProxyCIDRs: trusted})
	if err != nil {
		return nil, nil, nil, err
	}
	quota, err := admitpublic.New(admitpublic.Config{GlobalLimit: 500, SourceLimit: 100})
	if err != nil {
		return nil, nil, nil, err
	}
	var report func(bool)
	if len(metrics) > 0 {
		if recorder, ok := metrics[0].(interface{ ObserveMaintenanceRead(bool) }); ok {
			report = recorder.ObserveMaintenanceRead
		}
	}
	observer := observestate.NewWithReadObserver(reader, 5*time.Second, time.Second, report)
	handler, err := connectpublic.New(origin, observer, rate, quota, metrics...)
	if err != nil {
		return nil, nil, nil, err
	}
	ctx, cancel := context.WithCancel(parent)
	done := make(chan struct{})
	go func() { defer close(done); observer.Run(ctx) }()
	return handler, observer, func(ctx context.Context) error {
		cancel()
		select {
		case <-done:
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	}, nil
}
