package mediaroutes

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	snapshot "voice-platform/backend/internal/media/snapshot_livekit_presence"
	metrics "voice-platform/backend/internal/observability/http_metrics"
)

func TestRosterStreamRouteIsRetired(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	pool, err := pgxpool.New(ctx, "postgres://qa@127.0.0.1:1/qa?sslmode=disable")
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	mux := http.NewServeMux()
	_, stop, err := StartVoiceParticipantRoutes(ctx, mux, pool, authenticatesession.Service{}, snapshot.Client{}, metrics.New(), "", "")
	if err != nil {
		t.Fatal(err)
	}
	defer stop(context.Background())
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/api/v1/voice/rosters/events", nil))
	if response.Code != http.StatusNotFound {
		t.Fatalf("retired route returned %d, want 404", response.Code)
	}
}
