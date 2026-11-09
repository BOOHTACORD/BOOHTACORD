package mediaroutes

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	snapshot "voice-platform/backend/internal/media/snapshot_livekit_presence"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

func TestVoiceRoutesOwnOneSharedRealtimeSource(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	pool, err := pgxpool.New(ctx, "postgres://qa@127.0.0.1:1/qa?sslmode=disable")
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	mux := http.NewServeMux()
	factory, stop, err := StartVoiceParticipantRoutes(ctx, mux, pool, authenticatesession.Service{}, snapshot.Client{}, httpmetrics.New(), "", "")
	if err != nil || factory == nil || stop == nil {
		t.Fatalf("shared source: %v", err)
	}
	for _, target := range []struct{ method, path string }{{"GET", "/api/v1/voice/participants"}, {"POST", "/internal/livekit/roster"}} {
		request, _ := http.NewRequest(target.method, "http://example.test"+target.path, nil)
		_, pattern := mux.Handler(request)
		if pattern == "" {
			t.Fatalf("route missing: %s", target.path)
		}
	}
	shutdown, finish := context.WithTimeout(context.Background(), time.Second)
	defer finish()
	if err := stop(shutdown); err != nil {
		t.Fatal(err)
	}
}
