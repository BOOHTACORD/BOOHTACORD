package pool

import (
	"context"
	dto "github.com/prometheus/client_model/go"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"time"
)

func (m *Metrics) startExport() {
	stats, _ := m.meter.Float64ObservableGauge("boohtacord.incident.database.pool", metric.WithDescription("Current native pgxpool connection statistics."))
	wait, _ := m.meter.Float64ObservableCounter("boohtacord.incident.database.pool.empty.acquire.wait", metric.WithDescription("Cumulative time for successful acquisitions waiting on an empty pool."), metric.WithUnit("s"))
	events, _ := m.meter.Int64ObservableCounter("boohtacord.incident.database.pool.events", metric.WithDescription("Cumulative native empty and canceled acquisition counts."))
	pending, _ := m.meter.Float64ObservableGauge("boohtacord.incident.database.acquires.pending", metric.WithDescription("In-flight acquisition attempts including wait and construction."))
	m.registration, _ = m.meter.RegisterCallback(func(ctx context.Context, o metric.Observer) error {
		value := &dto.Metric{}
		_ = m.pending.Write(value)
		o.ObserveFloat64(pending, value.GetGauge().GetValue())
		s := m.snapshot()
		o.ObserveFloat64(wait, s["empty_acquire_wait_seconds_total"])
		o.ObserveInt64(events, int64(s["empty_acquires_total"]), metric.WithAttributes(attribute.String("stat", "empty_acquires")))
		o.ObserveInt64(events, int64(s["canceled_acquires_total"]), metric.WithAttributes(attribute.String("stat", "canceled_acquires")))
		for _, name := range []string{"acquired", "idle", "total", "max", "constructing"} {
			value := s[name]
			o.ObserveFloat64(stats, value, metric.WithAttributes(attribute.String("stat", name)))
		}
		return nil
	}, stats, pending, wait, events)
}
func (m *Metrics) exportAcquire(outcome string, elapsed time.Duration) {
	labels := metric.WithAttributes(attribute.String("outcome", outcome))
	m.exportTotal.Add(context.Background(), 1, labels)
	m.exportDuration.Record(context.Background(), elapsed.Seconds(), labels)
}

func (m *Metrics) StopExport() error {
	if m.registration != nil {
		return m.registration.Unregister()
	}
	return nil
}
