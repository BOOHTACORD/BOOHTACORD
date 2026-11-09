package httpmetrics

import (
	"net/http/httptest"
	"strings"
	"testing"
)

func TestMaintenanceReadMetricsUseOnlyFixedOutcomes(t *testing.T) {
	recorder := New()
	recorder.ObserveMaintenanceRead(true)
	recorder.ObserveMaintenanceRead(false)
	w := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(w, httptest.NewRequest("GET", "/metrics", nil))
	text := w.Body.String()
	for _, sample := range []string{
		`voice_platform_maintenance_observer_reads_total{outcome="success"} 1`,
		`voice_platform_maintenance_observer_reads_total{outcome="failure"} 1`,
	} {
		if !strings.Contains(text, sample) {
			t.Fatalf("missing fixed sample %q", sample)
		}
	}
}
