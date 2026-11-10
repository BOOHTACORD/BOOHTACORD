package rosterdependencymetrics

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"time"
)

type exports struct {
	callCount metric.Int64Counter
	calls     metric.Float64Histogram
}

func newExports() *exports {
	meter := otel.Meter("voice-platform/roster")
	calls, _ := meter.Float64Histogram("voice_platform_sfu_room_service_seconds", metric.WithUnit("s"), metric.WithExplicitBucketBoundaries(.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10))
	callCount, _ := meter.Int64Counter("voice_platform_sfu_room_service_calls_total")
	return &exports{callCount: callCount, calls: calls}
}
func (e *exports) call(method, outcome string, elapsed time.Duration) {
	counterOutcome := "success"
	if outcome != "success" {
		counterOutcome = "failure"
	}
	e.callCount.Add(context.Background(), 1, metric.WithAttributes(attribute.String("method", method), attribute.String("outcome", counterOutcome)))
	e.calls.Record(context.Background(), elapsed.Seconds(), metric.WithAttributes(attribute.String("method", method), attribute.String("outcome", outcome)))
}
