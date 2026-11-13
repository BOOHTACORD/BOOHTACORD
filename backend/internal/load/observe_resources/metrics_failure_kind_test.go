package observe_resources

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"voice-platform/backend/internal/load/validate_target"
)

func TestGuardPreservesBoundedMetricFailureKind(t *testing.T) {
	for _, stage := range []string{"resource_metrics_timeout", "resource_metrics_http", "resource_metrics_unavailable", "resource_metrics_invalid"} {
		t.Run(stage, func(t *testing.T) {
			s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				w.Header().Set("X-QA-Guard-Stage", stage)
				w.WriteHeader(http.StatusServiceUnavailable)
			}))
			defer s.Close()
			g := Guard{Manifest: validate_target.Manifest{Guard: s.URL}, Client: s.Client()}
			_, err := g.Check(context.Background())
			if got := Category(err); got != stage {
				t.Fatalf("got %q, want %q", got, stage)
			}
		})
	}
}
