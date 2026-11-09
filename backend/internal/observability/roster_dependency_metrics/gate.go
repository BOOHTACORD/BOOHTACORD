package rosterdependencymetrics

import (
	"context"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
)

type gateMetrics struct {
	count        *prometheus.CounterVec
	active       prometheus.Gauge
	exportCount  metric.Int64Counter
	exportActive metric.Int64UpDownCounter
}

func newGateMetrics(registry *prometheus.Registry) *gateMetrics {
	m := &gateMetrics{
		count:  prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_voice_presence_gate_total", Help: "Bounded volatile observation gate outcomes."}, []string{"outcome"}),
		active: prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_voice_presence_refreshes_active", Help: "Active scoped volatile SFU refreshes."}),
	}
	registry.MustRegister(m.count, m.active)
	meter := otel.Meter("voice-platform/roster")
	m.exportCount, _ = meter.Int64Counter("voice_platform_voice_presence_gate_total")
	m.exportActive, _ = meter.Int64UpDownCounter("voice_platform_voice_presence_refreshes_active")
	return m
}

func (m *Metrics) Gate(outcome string) {
	delta := 0
	switch outcome {
	case "started":
		delta = 1
	case "finished":
		delta = -1
	case "shared", "cached", "overloaded", "canceled":
	default:
		outcome = "other"
	}
	m.gate.count.WithLabelValues(outcome).Inc()
	m.gate.exportCount.Add(context.Background(), 1, metric.WithAttributes(attribute.String("outcome", outcome)))
	if delta != 0 {
		m.gate.active.Add(float64(delta))
		m.gate.exportActive.Add(context.Background(), int64(delta))
	}
}
