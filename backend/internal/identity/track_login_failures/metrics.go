package trackloginfailures

import "github.com/prometheus/client_golang/prometheus"

type Collector struct{ budget *Budget }

func NewCollector(b *Budget) *Collector { return &Collector{budget: b} }
func (c *Collector) Describe(ch chan<- *prometheus.Desc) {
	c.budget.decisions.Describe(ch)
	c.budget.outcomes.Describe(ch)
}
func (c *Collector) Collect(ch chan<- prometheus.Metric) {
	c.budget.decisions.Collect(ch)
	c.budget.outcomes.Collect(ch)
}
