package centralexport

import (
	"context"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"math"
	projection "voice-platform/backend/internal/observability/central_projection"
)

// RegisterMetrics observes delivery without network I/O or exposing endpoint,
// credentials or product principals. Loss becomes visible after delivery recovers.
func (r *Runtime) RegisterMetrics(provider metric.MeterProvider, version string) (func() error, error) {
	meter := provider.Meter("boohtacord/installation-delivery")
	queued, err := meter.Int64ObservableGauge("boohtacord.telemetry.queue.batches")
	if err != nil {
		return nil, err
	}
	dropped, err := meter.Int64ObservableCounter("boohtacord.telemetry.dropped.batches")
	if err != nil {
		return nil, err
	}
	build, err := meter.Int64ObservableGauge("boohtacord.telemetry.build.info")
	if err != nil {
		return nil, err
	}
	if !projection.ValidMetricVersion(version) {
		version = "unknown"
	}
	registration, err := meter.RegisterCallback(func(_ context.Context, observer metric.Observer) error {
		snapshot := r.Snapshot()
		count := snapshot.Dropped
		if count > math.MaxInt64 {
			count = math.MaxInt64
		}
		observer.ObserveInt64(queued, int64(snapshot.Queued))
		observer.ObserveInt64(dropped, int64(count))
		observer.ObserveInt64(build, 1, metric.WithAttributes(attribute.String("service_version", version)))
		return nil
	}, queued, dropped, build)
	if err != nil {
		return nil, err
	}
	return registration.Unregister, nil
}
