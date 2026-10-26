package password

import "github.com/prometheus/client_golang/prometheus"

type Collector struct {
	active, waiting, capacity *prometheus.Desc
	gate                      *admission
}

// NewCollector exports aggregate process-local state only on the API's private
// registry. There are no account, request, password or token labels.
func NewCollector() *Collector { return newCollector(kdfAdmission) }

func newCollector(gate *admission) *Collector {
	return &Collector{
		active:   prometheus.NewDesc("voice_platform_auth_kdf_active", "Reserved KDF slots retained until actual computation ends.", nil, nil),
		waiting:  prometheus.NewDesc("voice_platform_auth_kdf_waiting", "Waiting KDF operations; always zero under fail-fast admission.", nil, nil),
		capacity: prometheus.NewDesc("voice_platform_auth_kdf_capacity", "Maximum concurrent KDF operations per process.", nil, nil),
		gate:     gate,
	}
}

func (collector *Collector) Describe(ch chan<- *prometheus.Desc) {
	ch <- collector.active
	ch <- collector.waiting
	ch <- collector.capacity
	collector.gate.rejected.Describe(ch)
	collector.gate.cancelled.Describe(ch)
	collector.gate.duration.Describe(ch)
	collector.gate.work.Describe(ch)
}

func (collector *Collector) Collect(ch chan<- prometheus.Metric) {
	ch <- prometheus.MustNewConstMetric(collector.active, prometheus.GaugeValue, float64(len(collector.gate.slots)))
	ch <- prometheus.MustNewConstMetric(collector.waiting, prometheus.GaugeValue, 0)
	ch <- prometheus.MustNewConstMetric(collector.capacity, prometheus.GaugeValue, float64(cap(collector.gate.slots)))
	collector.gate.rejected.Collect(ch)
	collector.gate.cancelled.Collect(ch)
	collector.gate.duration.Collect(ch)
	collector.gate.work.Collect(ch)
}
