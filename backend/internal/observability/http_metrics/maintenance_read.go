package httpmetrics

import "github.com/prometheus/client_golang/prometheus"

func newMaintenanceReads() *prometheus.CounterVec {
	metric := prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "voice_platform_maintenance_observer_reads_total",
		Help: "Process-wide maintenance observation reads by fixed outcome.",
	}, []string{"outcome"})
	metric.WithLabelValues("success")
	metric.WithLabelValues("failure")
	return metric
}

func (recorder *Recorder) ObserveMaintenanceRead(ok bool) {
	outcome := "failure"
	if ok {
		outcome = "success"
	}
	recorder.maintenanceReads.WithLabelValues(outcome).Inc()
}
