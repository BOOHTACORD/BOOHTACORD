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
	if reader == nil {
		return nil, nil, errors.New("missing maintenance reader")
	}
	rate, err := ratelimit.New(ratelimit.Config{Limit: 240, Window: time.Minute, MaxSources: 10_000, TrustedProxyCIDRs: trusted})
	if err != nil {
		return nil, nil, err
	}
	quota, err := admitpublic.New(admitpublic.Config{GlobalLimit: 500, SourceLimit: 100})
	if err != nil {
		return nil, nil, err
	}
	observer := observestate.New(reader, 5*time.Second, time.Second)
	handler, err := connectpublic.New(origin, observer, rate, quota)
	if err != nil {
		return nil, nil, err
	}
	ctx, cancel := context.WithCancel(parent)
	done := make(chan struct{})
	go func() { defer close(done); observer.Run(ctx) }()
	return handler, func(ctx context.Context) error {
		cancel()
		select {
		case <-done:
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	}, nil
}
