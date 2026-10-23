package admitlogin

import "github.com/prometheus/client_golang/prometheus"

type Stats struct{ Accounts, Capacity, InFlight int }

func (budget *Budget) Stats() Stats {
	budget.mutex.Lock()
	defer budget.mutex.Unlock()
	return Stats{len(budget.entries), budget.config.MaxAccounts, budget.inFlight}
}

type Collector struct {
	budget                     *Budget
	active, capacity, inFlight *prometheus.Desc
}

func NewCollector(budget *Budget) *Collector {
	return &Collector{budget: budget,
		active:   prometheus.NewDesc("voice_platform_login_budgets_active", "Retained process-local login budgets; includes expired in-flight work.", nil, nil),
		capacity: prometheus.NewDesc("voice_platform_login_budgets_capacity", "Maximum process-local login budget entries.", nil, nil),
		inFlight: prometheus.NewDesc("voice_platform_login_reservations_active", "Login reservations retained until actual Login completion.", nil, nil),
	}
}
func (collector *Collector) Describe(ch chan<- *prometheus.Desc) {
	ch <- collector.active
	ch <- collector.capacity
	ch <- collector.inFlight
	collector.budget.decisions.Describe(ch)
	collector.budget.outcomes.Describe(ch)
	collector.budget.duration.Describe(ch)
}
func (collector *Collector) Collect(ch chan<- prometheus.Metric) {
	stats := collector.budget.Stats()
	ch <- prometheus.MustNewConstMetric(collector.active, prometheus.GaugeValue, float64(stats.Accounts))
	ch <- prometheus.MustNewConstMetric(collector.capacity, prometheus.GaugeValue, float64(stats.Capacity))
	ch <- prometheus.MustNewConstMetric(collector.inFlight, prometheus.GaugeValue, float64(stats.InFlight))
	collector.budget.decisions.Collect(ch)
	collector.budget.outcomes.Collect(ch)
	collector.budget.duration.Collect(ch)
}
