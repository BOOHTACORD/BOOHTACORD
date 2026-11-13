package observe_resources

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"voice-platform/backend/internal/load/validate_target"
)

func TestGuard503ExposesOnlyAllowlistedFailureStage(t *testing.T) {
	stage := "fixture_verification"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("X-QA-Guard-Stage", stage)
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer server.Close()
	g := Guard{Manifest: validate_target.Manifest{Guard: server.URL}, Client: server.Client()}
	for _, item := range []struct{ stage, want string }{
		{"fixture_verification", "fixture_verification"},
		{"resource_snapshot", "resource_snapshot"},
		{"private-detail", "denied"},
	} {
		stage = item.stage
		_, err := g.Check(context.Background())
		if Category(err) != item.want {
			t.Fatalf("unexpected category %q", Category(err))
		}
	}
}
