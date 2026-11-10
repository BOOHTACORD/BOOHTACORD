package rosterdependencymetrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"time"
)

type Metrics struct {
	classes  *failureClasses
	fresh    *freshness
	gate     *gateMetrics
	snapshot *snapshotExports
	export   *exports
	calls    *prometheus.HistogramVec
}

func New(registry *prometheus.Registry) *Metrics {
	m := &Metrics{classes: newFailureClasses(registry), fresh: newFreshness(registry), gate: newGateMetrics(registry), snapshot: newSnapshotExports(), export: newExports(),
		calls: prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_sfu_room_service_seconds", Help: "RoomService transport latency by bounded method/outcome."}, []string{"method", "outcome"}),
	}
	registry.MustRegister(m.calls)
	return m
}
func (m *Metrics) Call(method, outcome string, elapsed time.Duration) {
	if method != "ListRooms" && method != "ListParticipants" {
		method = "other"
	}
	switch outcome {
	case "success", "error", "transport_error", "http_error", "timeout", "canceled", "overload":
	default:
		outcome = "error"
	}
	m.export.call(method, outcome, elapsed)
	m.fresh.call(method, outcome)
	m.calls.WithLabelValues(method, outcome).Observe(elapsed.Seconds())
}
