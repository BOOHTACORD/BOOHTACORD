package rosterdependencymetrics

import (
	"context"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"sync"
	"time"
)

type freshness struct {
	mu               sync.Mutex
	configured       float64
	latest           map[string][2]float64
	attempt, success *prometheus.GaugeVec
	enabled          prometheus.Gauge
}

func newFreshness(registry *prometheus.Registry) *freshness {
	f := &freshness{latest: map[string][2]float64{},
		attempt: prometheus.NewGaugeVec(prometheus.GaugeOpts{Name: "voice_platform_sfu_room_service_last_attempt_timestamp_seconds", Help: "Last RoomService transport attempt by bounded method."}, []string{"method"}),
		success: prometheus.NewGaugeVec(prometheus.GaugeOpts{Name: "voice_platform_sfu_room_service_last_success_timestamp_seconds", Help: "Last successful RoomService transport response; absent until success."}, []string{"method"}),
		enabled: prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_sfu_room_service_configured", Help: "Whether a validated private RoomService client is configured."}),
	}
	registry.MustRegister(f.attempt, f.success, f.enabled)
	meter := otel.Meter("voice-platform/roster")
	attempt, _ := meter.Float64ObservableGauge("voice_platform_sfu_room_service_last_attempt_timestamp_seconds", metric.WithUnit("s"))
	success, _ := meter.Float64ObservableGauge("voice_platform_sfu_room_service_last_success_timestamp_seconds", metric.WithUnit("s"))
	configured, _ := meter.Float64ObservableGauge("voice_platform_sfu_room_service_configured")
	_, _ = meter.RegisterCallback(func(ctx context.Context, observer metric.Observer) error {
		f.mu.Lock()
		defer f.mu.Unlock()
		observer.ObserveFloat64(configured, f.configured)
		for method, value := range f.latest {
			labels := metric.WithAttributes(attribute.String("method", method))
			observer.ObserveFloat64(attempt, value[0], labels)
			if value[1] != 0 {
				observer.ObserveFloat64(success, value[1], labels)
			}
		}
		return nil
	}, attempt, success, configured)
	return f
}

func (f *freshness) call(method, outcome string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	at := float64(time.Now().Unix())
	value := f.latest[method]
	value[0] = at
	f.attempt.WithLabelValues(method).Set(at)
	if outcome == "success" {
		value[1] = at
		f.success.WithLabelValues(method).Set(at)
	}
	f.latest[method] = value
}

func (m *Metrics) Configured(configured bool) {
	m.fresh.mu.Lock()
	defer m.fresh.mu.Unlock()
	value := 0.
	if configured {
		value = 1
	}
	m.fresh.configured = value
	m.fresh.enabled.Set(value)
}
