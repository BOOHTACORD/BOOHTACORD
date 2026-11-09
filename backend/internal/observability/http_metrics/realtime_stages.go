package httpmetrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"time"
)

func newRealtimeStages() *prometheus.HistogramVec {
	metric := prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "voice_platform_realtime_event_stage_seconds",
		Help:    "Successful event time before and inside the WebSocket event handler.",
		Buckets: []float64{0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10},
	}, []string{"stage"})
	metric.WithLabelValues("before_handler")
	metric.WithLabelValues("handler")
	return metric
}

func (r *Recorder) ObserveRealtimeEventStages(beforeHandler, handler time.Duration) {
	if beforeHandler < 0 || handler < 0 {
		return
	}
	r.eventStages.WithLabelValues("before_handler").Observe(beforeHandler.Seconds())
	r.eventStages.WithLabelValues("handler").Observe(handler.Seconds())
}
