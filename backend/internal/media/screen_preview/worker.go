package screenpreview

import (
	"context"
	"errors"
	"log/slog"
	"time"
)

type CaptureReconciler interface {
	Reconcile(context.Context, []ActiveGeneration) error
}

func (service Service) PollCaptures(ctx context.Context) error {
	var failures []error
	for _, active := range service.store.Active() {
		frame, err := service.capturer.Latest(ctx, active.LeaseID, active.GenerationID)
		if errors.Is(err, ErrNoUpdate) {
			continue
		}
		if err != nil {
			failures = append(failures, ErrUnavailable)
			continue
		}
		jpeg, err := NormalizeJPEG(frame.JPEG)
		if err != nil {
			continue
		}
		revision, changed, err := service.store.Capture(active.LeaseID, active.GenerationID, frame.Fingerprint, jpeg)
		if errors.Is(err, ErrStaleGeneration) {
			continue
		}
		if err != nil {
			failures = append(failures, ErrUnavailable)
			continue
		}
		if changed && service.hints != nil {
			service.hints.Updated(ctx, active.LeaseID, active.GenerationID, revision)
		}
	}
	return errors.Join(failures...)
}

func (service Service) retire(ctx context.Context, active ActiveGeneration) {
	_ = service.store.Invalidate(active.LeaseID, active.GenerationID)
	_ = service.capturer.Stop(ctx, active.LeaseID, active.GenerationID, active.TrackSID)
	if service.hints != nil {
		service.hints.Invalidated(ctx, active.LeaseID, active.GenerationID)
	}
}

func (service Service) Run(ctx context.Context) {
	service.run(ctx, CapturePollInterval, CaptureReconcileRetryInterval)
}

func (service Service) run(ctx context.Context, pollInterval, reconcileRetryInterval time.Duration) {
	reconciler, canReconcile := service.capturer.(CaptureReconciler)
	var reconcileRetryAt time.Time
	if canReconcile {
		if err := reconciler.Reconcile(ctx, service.store.Active()); err != nil {
			slog.Warn("screen preview Egress reconciliation failed")
			reconcileRetryAt = time.Now().Add(reconcileRetryInterval)
		}
	}
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			service.shutdownCaptures()
			return
		case <-ticker.C:
			if err := service.PollCaptures(ctx); err != nil {
				slog.Warn("screen preview capture poll failed")
			}
			service.reapExpired(ctx)
			if canReconcile && !reconcileRetryAt.IsZero() && !time.Now().Before(reconcileRetryAt) {
				if err := reconciler.Reconcile(ctx, service.store.Active()); err != nil {
					slog.Warn("screen preview Egress reconciliation retry failed")
					reconcileRetryAt = time.Now().Add(reconcileRetryInterval)
				} else {
					reconcileRetryAt = time.Time{}
				}
			}
		}
	}
}

func (service Service) Start(parent context.Context) func(context.Context) error {
	ctx, cancel := context.WithCancel(parent)
	done := make(chan struct{})
	go func() {
		defer close(done)
		service.Run(ctx)
	}()
	return func(stopContext context.Context) error {
		cancel()
		select {
		case <-done:
			return nil
		case <-stopContext.Done():
			return stopContext.Err()
		}
	}
}

func (service Service) reapExpired(ctx context.Context) {
	for _, capture := range service.capturer.Active() {
		generationID, _, trackSID, found := service.store.Current(capture.LeaseID)
		if found && generationID == capture.GenerationID {
			continue
		}
		_ = service.capturer.Stop(ctx, capture.LeaseID, capture.GenerationID, trackSID)
	}
}

func (service Service) shutdownCaptures() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if reconciler, ok := service.capturer.(CaptureReconciler); ok {
		if err := reconciler.Reconcile(ctx, nil); err != nil {
			slog.Warn("screen preview Egress shutdown failed")
		}
		return
	}
	for _, capture := range service.capturer.Active() {
		_, _, trackSID, _ := service.store.Current(capture.LeaseID)
		_ = service.capturer.Stop(ctx, capture.LeaseID, capture.GenerationID, trackSID)
	}
}
