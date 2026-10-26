package observedelivery

import (
	"context"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	"time"
)

type Runtime struct {
	health  *prometheus.GaugeVec
	tick    *prometheus.GaugeVec
	latency *prometheus.HistogramVec
}

func NewRuntime() *Runtime {
	return &Runtime{
		tick:    prometheus.NewGaugeVec(prometheus.GaugeOpts{Name: "boohtacord_notification_worker_tick_timestamp_seconds", Help: "Last bounded worker iteration wall clock"}, []string{"worker"}),
		health:  prometheus.NewGaugeVec(prometheus.GaugeOpts{Name: "boohtacord_notification_worker_health", Help: "Last bounded worker iteration succeeded; scrape absence is separate"}, []string{"worker"}),
		latency: prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "boohtacord_notification_processing_seconds", Help: "Technical processing delay after scheduled due time; no OS display claim", Buckets: []float64{.01, .05, .1, .25, .5, 1, 2, 5, 15, 30, 60}}, []string{"stage"}),
	}
}
func (r *Runtime) Describe(c chan<- *prometheus.Desc) {
	r.tick.Describe(c)
	r.health.Describe(c)
	r.latency.Describe(c)
}
func (r *Runtime) Collect(c chan<- prometheus.Metric) {
	r.tick.Collect(c)
	r.health.Collect(c)
	r.latency.Collect(c)
}
func (r *Runtime) Tick(worker string, err error) {
	if r == nil {
		return
	}
	if worker != "plan" && worker != "send" {
		return
	}
	value := float64(1)
	if err != nil {
		value = 0
	}
	r.health.WithLabelValues(worker).Set(value)
	r.tick.WithLabelValues(worker).Set(float64(time.Now().Unix()))
}
func (r *Runtime) Delay(stage string, due, now time.Time) {
	if r == nil || due.IsZero() {
		return
	}
	if stage != "eligible" && stage != "provider_accepted" {
		return
	}
	r.latency.WithLabelValues(stage).Observe(max(0, now.Sub(due).Seconds()))
}

// No capability references, target IDs, raw provider errors or payload attributes.
func Span(ctx context.Context, name string) (context.Context, func()) {
	switch name {
	case "notification.plan", "notification.claim", "notification.attempt", "notification.resolve":
	default:
		return ctx, func() {}
	}
	ctx, span := otel.Tracer("boohtacord/notifications").Start(ctx, name)
	return ctx, func() { span.End() }
}
