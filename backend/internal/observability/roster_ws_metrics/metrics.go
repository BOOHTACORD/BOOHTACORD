// Package rosterwsmetrics publishes bounded, identity-free roster WS signals.
package rosterwsmetrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"sync/atomic"
	"time"
)

type Metrics struct {
	active                     prometheus.Gauge
	initial, delivery, refresh *prometheus.CounterVec
	duration                   prometheus.Histogram
	last, enabled              prometheus.Gauge
	lastUnix                   atomic.Int64
	export                     *exports
}

func New(registry *prometheus.Registry) *Metrics {
	m := &Metrics{
		active:   prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_voice_roster_ws_subscribers", Help: "Current authenticated roster WebSocket subscribers."}),
		initial:  prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_voice_roster_ws_initial_total", Help: "First roster frame outcomes."}, []string{"outcome"}),
		delivery: prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_voice_roster_ws_delivery_total", Help: "Roster frame delivery outcomes."}, []string{"outcome"}),
		refresh:  prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_voice_roster_ws_refresh_total", Help: "Completed authoritative coordinator refreshes."}, []string{"outcome"}),
		duration: prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_voice_roster_ws_delivery_seconds", Help: "Roster authorization and frame delivery latency."}),
		last:     prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_voice_roster_ws_last_success_timestamp_seconds", Help: "Latest successful authoritative roster refresh."}),
		enabled:  prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_voice_roster_ws_observation_enabled", Help: "WebSocket roster observation is installed."}),
	}
	registry.MustRegister(m.active, m.initial, m.delivery, m.refresh, m.duration, m.last, m.enabled)
	m.enabled.Set(1)
	for _, outcome := range []string{"success", "unavailable", "failure"} {
		m.initial.WithLabelValues(outcome)
		m.delivery.WithLabelValues(outcome)
	}
	for _, outcome := range []string{"success", "failure"} {
		m.refresh.WithLabelValues(outcome)
	}
	m.export = newExports(m)
	return m
}

func (m *Metrics) Open()  { m.active.Inc(); m.export.open() }
func (m *Metrics) Close() { m.active.Dec(); m.export.close() }
func (m *Metrics) Delivery(elapsed time.Duration, outcome string, initial bool) {
	if outcome != "success" && outcome != "unavailable" {
		outcome = "failure"
	}
	if elapsed < 0 {
		elapsed = 0
	}
	m.delivery.WithLabelValues(outcome).Inc()
	if initial {
		m.initial.WithLabelValues(outcome).Inc()
	}
	m.duration.Observe(elapsed.Seconds())
	m.export.deliveryAttempt(elapsed, outcome, initial)
}
func (m *Metrics) Refresh(success bool) {
	outcome := "failure"
	if success {
		outcome = "success"
		at := time.Now().Unix()
		m.lastUnix.Store(at)
		m.last.Set(float64(at))
	}
	m.refresh.WithLabelValues(outcome).Inc()
	m.export.refreshAttempt(outcome)
}
