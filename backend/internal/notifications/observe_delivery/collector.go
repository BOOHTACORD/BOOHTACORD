package observedelivery

import (
	"context"
	"github.com/jackc/pgx/v5"
	"github.com/prometheus/client_golang/prometheus"
	"time"
)

type ObserverDatabase interface {
	QueryRow(context.Context, string, ...any) pgx.Row
	Query(context.Context, string, ...any) (pgx.Rows, error)
}
type Collector struct {
	database                                 ObserverDatabase
	up, queue, age, enabled, active, results *prometheus.Desc
}

func NewCollector(database ObserverDatabase) *Collector {
	return &Collector{database: database,
		up:      prometheus.NewDesc("boohtacord_notification_observer_up", "Notification database observation available", nil, nil),
		queue:   prometheus.NewDesc("boohtacord_notification_queue", "Durable jobs by bounded stage", []string{"stage"}, nil),
		age:     prometheus.NewDesc("boohtacord_notification_oldest_due_seconds", "Technical delay after grace/attention due time", nil, nil),
		enabled: prometheus.NewDesc("boohtacord_notification_sending_enabled", "Configured and not killed", nil, nil),
		active:  prometheus.NewDesc("boohtacord_notification_active_subscriptions", "Active unexpired routes with issuing session", []string{"transport"}, nil),
		results: prometheus.NewDesc("boohtacord_notification_results_total", "Durable outcomes; acceptance is not observed display or read", []string{"stage", "reason", "transport"}, nil)}
}
func (c *Collector) Describe(out chan<- *prometheus.Desc) {
	for _, d := range []*prometheus.Desc{c.up, c.queue, c.age, c.enabled, c.active, c.results} {
		out <- d
	}
}

type sample struct {
	desc   *prometheus.Desc
	kind   prometheus.ValueType
	value  float64
	labels []string
}

func (c *Collector) Collect(out chan<- prometheus.Metric) {
	values, err := c.read()
	if err != nil {
		out <- prometheus.MustNewConstMetric(c.up, prometheus.GaugeValue, 0)
		return
	}
	out <- prometheus.MustNewConstMetric(c.up, prometheus.GaugeValue, 1)
	for _, s := range values {
		out <- prometheus.MustNewConstMetric(s.desc, s.kind, s.value, s.labels...)
	}
}
func (c *Collector) read() ([]sample, error) {
	if c.database == nil {
		return nil, context.Canceled
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	var intents, deliveries, inflight int
	var enabled bool
	var age float64
	err := c.database.QueryRow(ctx, `SELECT intent_pending,delivery_pending,operator_enabled AND NOT kill_switch,
 (SELECT count(*) FROM notification_deliveries WHERE state='claimed' AND lease_until>now()),
 COALESCE((SELECT greatest(0,extract(epoch FROM now()-min(due_at))) FROM notification_deliveries WHERE state IN('pending','retry') AND due_at<now()),0)
 FROM notification_runtime_policy WHERE singleton`).Scan(&intents, &deliveries, &enabled, &inflight, &age)
	if err != nil {
		return nil, err
	}
	flag := float64(0)
	if enabled {
		flag = 1
	}
	values := []sample{{c.queue, prometheus.GaugeValue, float64(intents), []string{"intent"}}, {c.queue, prometheus.GaugeValue, float64(deliveries), []string{"delivery"}}, {c.queue, prometheus.GaugeValue, float64(inflight), []string{"inflight"}}, {c.age, prometheus.GaugeValue, age, nil}, {c.enabled, prometheus.GaugeValue, flag, nil}}
	rows, err := c.database.Query(ctx, `SELECT metric,reason,transport,value FROM notification_counters LIMIT 2048`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	totals := map[[3]string]float64{}
	for rows.Next() {
		var metric, reason, transport string
		var value float64
		if err = rows.Scan(&metric, &reason, &transport, &value); err != nil {
			return nil, err
		}
		if !Metrics[metric] {
			continue
		}
		if transport != "web_push" && transport != "mobile_relay" {
			transport = "none"
		}
		totals[[3]string{metric, Reason(reason), transport}] += value
	}
	if err = rows.Err(); err != nil {
		return nil, err
	}
	rows.Close()
	for key, value := range totals {
		values = append(values, sample{c.results, prometheus.CounterValue, value, []string{key[0], key[1], key[2]}})
	}
	for _, transport := range []string{"web_push", "mobile_relay"} {
		var count float64
		err = c.database.QueryRow(ctx, `SELECT count(*) FROM notification_devices d JOIN sessions s ON s.token_digest=d.session_digest JOIN users u ON u.id=d.account_id WHERE d.transport=$1 AND d.state='active' AND d.expires_at>now() AND s.revoked_at IS NULL AND s.expires_at>now() AND u.blocked_at IS NULL`, transport).Scan(&count)
		if err != nil {
			return nil, err
		}
		values = append(values, sample{c.active, prometheus.GaugeValue, count, []string{transport}})
	}
	return values, nil
}

var Metrics = map[string]bool{"intent_created": true, "eligible": true, "suppressed": true, "attempt": true, "relay_accepted": true, "provider_accepted": true, "retry": true, "expired": true, "invalid_binding": true, "ambiguous": true, "permanent_failure": true, "opened": true, "read": true, "queue_drop": true}
