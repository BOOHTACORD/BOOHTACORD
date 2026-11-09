package rosterdependencymetrics

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"time"
)

type snapshotExports struct {
	snapshots       metric.Int64Counter
	failures        metric.Int64Counter
	duration, rooms metric.Float64Histogram
}

func newSnapshotExports() *snapshotExports {
	meter := otel.Meter("voice-platform/roster")
	snapshots, _ := meter.Int64Counter("voice_platform_voice_roster_snapshots_total")
	failures, _ := meter.Int64Counter("voice_platform_voice_roster_failures_total")
	duration, _ := meter.Float64Histogram("voice_platform_voice_roster_snapshot_seconds", metric.WithUnit("s"), metric.WithExplicitBucketBoundaries(.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10))
	rooms, _ := meter.Float64Histogram("voice_platform_voice_roster_requested_rooms")
	return &snapshotExports{snapshots: snapshots, failures: failures, duration: duration, rooms: rooms}
}

func (m *Metrics) Snapshot(elapsed time.Duration, rooms int, failed bool) {
	outcome := "success"
	if failed {
		outcome = "failure"
	}
	m.snapshot.snapshots.Add(context.Background(), 1, metric.WithAttributes(attribute.String("outcome", outcome)))
	m.snapshot.duration.Record(context.Background(), elapsed.Seconds())
	m.snapshot.rooms.Record(context.Background(), float64(rooms))
}

// Caller passes the same stage allowlist used by the private Prometheus metric.
func (m *Metrics) Failure(stage string) {
	m.snapshot.failures.Add(context.Background(), 1, metric.WithAttributes(attribute.String("stage", stage)))
}
