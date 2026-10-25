package observequeue

import (
	"context"
	"github.com/jackc/pgx/v5"
	"github.com/prometheus/client_golang/prometheus"
	"time"
)

type Database interface {
	QueryRow(context.Context, string, ...any) pgx.Row
	Query(context.Context, string, ...any) (pgx.Rows, error)
}
type Collector struct {
	database                              Database
	namespace                             string
	up, pending, oldest, enabled, results *prometheus.Desc
}

func New(database Database, namespace string) *Collector {
	return &Collector{database: database, namespace: namespace,
		up:      prometheus.NewDesc("boohtacord_push_relay_observer_up", "Whether relay database observation succeeded", []string{"namespace"}, nil),
		pending: prometheus.NewDesc("boohtacord_push_relay_queue_pending", "Durable pending relay jobs", []string{"namespace"}, nil),
		oldest:  prometheus.NewDesc("boohtacord_push_relay_queue_oldest_seconds", "Age of oldest pending relay job", []string{"namespace"}, nil),
		enabled: prometheus.NewDesc("boohtacord_push_relay_sending_enabled", "Configured and not killed relay sending", []string{"namespace"}, nil),
		results: prometheus.NewDesc("boohtacord_push_relay_results_total", "Durable relay outcomes; provider acceptance is not delivery", []string{"outcome", "namespace"}, nil)}
}
func (c *Collector) Describe(out chan<- *prometheus.Desc) {
	for _, d := range []*prometheus.Desc{c.up, c.pending, c.oldest, c.enabled, c.results} {
		out <- d
	}
}
func (c *Collector) Collect(out chan<- prometheus.Metric) {
	ns := c.namespace
	if ns != "staging" && ns != "production" {
		return
	}
	emit := func(d *prometheus.Desc, kind prometheus.ValueType, value float64, labels ...string) {
		out <- prometheus.MustNewConstMetric(d, kind, value, labels...)
	}
	if c.database == nil {
		emit(c.up, prometheus.GaugeValue, 0, ns)
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	var pending int
	var enabled bool
	var oldest *time.Time
	err := c.database.QueryRow(ctx, `SELECT pending,enabled AND NOT kill_switch,(SELECT min(created_at)FROM relay_jobs WHERE state IN('pending','claimed','retry'))FROM relay_policy WHERE singleton`).Scan(&pending, &enabled, &oldest)
	if err != nil {
		emit(c.up, prometheus.GaugeValue, 0, ns)
		return
	}
	rows, err := c.database.Query(ctx, `SELECT outcome,value FROM relay_counters WHERE namespace=$1 LIMIT 16`, ns)
	if err != nil {
		emit(c.up, prometheus.GaugeValue, 0, ns)
		return
	}
	defer rows.Close()
	counters := map[string]float64{}
	for rows.Next() {
		var outcome string
		var value float64
		if rows.Scan(&outcome, &value) != nil {
			emit(c.up, prometheus.GaugeValue, 0, ns)
			return
		}
		counters[outcome] = value
	}
	if rows.Err() != nil {
		emit(c.up, prometheus.GaugeValue, 0, ns)
		return
	}
	emit(c.up, prometheus.GaugeValue, 1, ns)
	emit(c.pending, prometheus.GaugeValue, float64(pending), ns)
	age := float64(0)
	if oldest != nil {
		age = max(0, time.Since(*oldest).Seconds())
	}
	emit(c.oldest, prometheus.GaugeValue, age, ns)
	available := float64(0)
	if enabled {
		available = 1
	}
	emit(c.enabled, prometheus.GaugeValue, available, ns)
	for _, outcome := range []string{"accepted_by_relay", "accepted_by_provider", "retry", "delivery_unknown", "invalid_binding", "permanent_failure", "expired", "rejected", "revoked"} {
		emit(c.results, prometheus.CounterValue, counters[outcome], outcome, ns)
	}
}
