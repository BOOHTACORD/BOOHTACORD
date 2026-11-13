package pool

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/metric"
)

type Metrics struct {
	meter          metric.Meter
	exportTotal    metric.Int64Counter
	exportDuration metric.Float64Histogram
	registration   metric.Registration
	pool           *pgxpool.Pool
	sessionPool    *pgxpool.Pool
	pending        prometheus.Gauge
	acquires       *prometheus.CounterVec
	duration       *prometheus.HistogramVec
	stats          map[string]*prometheus.Desc
	partitionStats *prometheus.Desc
}

func NewMetrics() *Metrics {
	m := &Metrics{meter: otel.Meter("boohtacord/incident-pool"), pending: prometheus.NewGauge(prometheus.GaugeOpts{Name: "voice_platform_database_acquires_pending", Help: "In-flight acquisition attempts; includes connection construction, not only saturation waiters."}),
		acquires: prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_database_acquires_total", Help: "Pool acquisition outcomes, including failure and timeout."}, []string{"outcome"}),
		duration: prometheus.NewHistogramVec(prometheus.HistogramOpts{Name: "voice_platform_database_acquire_duration_seconds", Help: "Pool acquisition latency including failures."}, []string{"outcome"}), stats: make(map[string]*prometheus.Desc)}
	m.partitionStats = prometheus.NewDesc("voice_platform_database_partition_connections", "Connections by bounded pool partition and state.", []string{"partition", "state"}, nil)
	for _, name := range []string{"acquired", "idle", "total", "max", "constructing", "empty_acquires_total", "empty_acquire_wait_seconds_total", "canceled_acquires_total"} {
		m.stats[name] = prometheus.NewDesc("voice_platform_database_pool_"+name, "Native pgxpool statistic: "+name, nil, nil)
	}
	m.exportTotal, _ = m.meter.Int64Counter("boohtacord.incident.database.acquires", metric.WithDescription("Native pool acquisition outcomes including timeouts and failures."))
	m.exportDuration, _ = m.meter.Float64Histogram("boohtacord.incident.database.acquire.duration", metric.WithDescription("Pool acquisition duration including failed waits."), metric.WithUnit("s"), metric.WithExplicitBucketBoundaries(.001, .005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5))
	return m
}
func (m *Metrics) Describe(c chan<- *prometheus.Desc) {
	m.pending.Describe(c)
	m.acquires.Describe(c)
	m.duration.Describe(c)
	for _, d := range m.stats {
		c <- d
	}
	c <- m.partitionStats
}
func (m *Metrics) Collect(c chan<- prometheus.Metric) {
	m.pending.Collect(c)
	m.acquires.Collect(c)
	m.duration.Collect(c)
	if m.pool == nil {
		return
	}
	for name, value := range m.snapshot() {
		kind := prometheus.GaugeValue
		if name == "empty_acquires_total" || name == "empty_acquire_wait_seconds_total" || name == "canceled_acquires_total" {
			kind = prometheus.CounterValue
		}
		c <- prometheus.MustNewConstMetric(m.stats[name], kind, value)
	}
	for _, partition := range m.partitions() {
		for state, value := range partitionValues(partition.pool) {
			c <- prometheus.MustNewConstMetric(m.partitionStats, prometheus.GaugeValue, value, partition.name, state)
		}
	}
}
