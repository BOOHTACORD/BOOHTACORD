package httpmetrics

import (
	"context"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
)

type realtimeCapabilities struct {
	active       *prometheus.GaugeVec
	total        *prometheus.CounterVec
	activeExport metric.Int64UpDownCounter
	totalExport  metric.Int64Counter
}

func newRealtimeCapabilities(registry *prometheus.Registry) *realtimeCapabilities {
	m := &realtimeCapabilities{
		active: prometheus.NewGaugeVec(prometheus.GaugeOpts{Name: "voice_platform_realtime_capability_connections_active", Help: "Accepted authenticated sockets by claimed realtime feature set."}, []string{"capability"}),
		total:  prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_realtime_capability_connections_total", Help: "Accepted authenticated sockets by claimed realtime feature set."}, []string{"capability"}),
	}
	registry.MustRegister(m.active, m.total)
	meter := otel.Meter("voice-platform/realtime-capabilities")
	m.activeExport, _ = meter.Int64UpDownCounter("voice_platform_realtime_capability_connections_active")
	m.totalExport, _ = meter.Int64Counter("voice_platform_realtime_capability_connections_total")
	for _, class := range []string{"neither", "roster_only", "maintenance_only", "both"} {
		m.active.WithLabelValues(class)
		m.total.WithLabelValues(class)
		attrs := metric.WithAttributes(attribute.String("capability", class))
		m.activeExport.Add(context.Background(), 0, attrs)
		m.totalExport.Add(context.Background(), 0, attrs)
	}
	return m
}

func validCapabilityClass(class string) bool {
	switch class {
	case "neither", "roster_only", "maintenance_only", "both":
		return true
	}
	return false
}

func (r *Recorder) RealtimeCapabilityOpened(class string) {
	if !validCapabilityClass(class) {
		return
	}
	r.capabilities.active.WithLabelValues(class).Inc()
	r.capabilities.total.WithLabelValues(class).Inc()
	attrs := metric.WithAttributes(attribute.String("capability", class))
	r.capabilities.activeExport.Add(context.Background(), 1, attrs)
	r.capabilities.totalExport.Add(context.Background(), 1, attrs)
}
func (r *Recorder) RealtimeCapabilityClosed(class string) {
	if !validCapabilityClass(class) {
		return
	}
	r.capabilities.active.WithLabelValues(class).Dec()
	r.capabilities.activeExport.Add(context.Background(), -1, metric.WithAttributes(attribute.String("capability", class)))
}
