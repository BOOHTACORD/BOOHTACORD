package rosterwsmetrics

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"time"
)

type exports struct {
	active                     metric.Int64UpDownCounter
	initial, delivery, refresh metric.Int64Counter
	duration                   metric.Float64Histogram
}

func newExports(m *Metrics) *exports {
	meter := otel.Meter("voice-platform/roster-ws")
	active, _ := meter.Int64UpDownCounter("voice_platform_voice_roster_ws_subscribers")
	initial, _ := meter.Int64Counter("voice_platform_voice_roster_ws_initial_total")
	delivery, _ := meter.Int64Counter("voice_platform_voice_roster_ws_delivery_total")
	refresh, _ := meter.Int64Counter("voice_platform_voice_roster_ws_refresh_total")
	duration, _ := meter.Float64Histogram("voice_platform_voice_roster_ws_delivery_seconds", metric.WithUnit("s"), metric.WithExplicitBucketBoundaries(.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10))
	latest, _ := meter.Float64ObservableGauge("voice_platform_voice_roster_ws_last_success_timestamp_seconds", metric.WithUnit("s"))
	enabled, _ := meter.Float64ObservableGauge("voice_platform_voice_roster_ws_observation_enabled")
	_, _ = meter.RegisterCallback(func(_ context.Context, observer metric.Observer) error {
		observer.ObserveFloat64(latest, float64(m.lastUnix.Load()))
		observer.ObserveFloat64(enabled, 1)
		return nil
	}, latest, enabled)
	for _, outcome := range []string{"success", "unavailable", "failure"} {
		attr := metric.WithAttributes(attribute.String("outcome", outcome))
		initial.Add(context.Background(), 0, attr)
		delivery.Add(context.Background(), 0, attr)
	}
	for _, outcome := range []string{"success", "failure"} {
		refresh.Add(context.Background(), 0, metric.WithAttributes(attribute.String("outcome", outcome)))
	}
	active.Add(context.Background(), 0)
	return &exports{active: active, initial: initial, delivery: delivery, refresh: refresh, duration: duration}
}
func (e *exports) open()  { e.active.Add(context.Background(), 1) }
func (e *exports) close() { e.active.Add(context.Background(), -1) }
func (e *exports) deliveryAttempt(elapsed time.Duration, outcome string, first bool) {
	ctx := context.Background()
	attr := metric.WithAttributes(attribute.String("outcome", outcome))
	e.delivery.Add(ctx, 1, attr)
	if first {
		e.initial.Add(ctx, 1, attr)
	}
	e.duration.Record(ctx, elapsed.Seconds())
}
func (e *exports) refreshAttempt(outcome string) {
	e.refresh.Add(context.Background(), 1, metric.WithAttributes(attribute.String("outcome", outcome)))
}
