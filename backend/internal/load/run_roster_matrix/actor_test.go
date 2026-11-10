package runrostermatrix

import (
	"context"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/coder/websocket"
	"voice-platform/backend/internal/load/validate_target"
)

func TestCandidateActorWaitsForAllThreeInitialEvents(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/auth/login":
			http.SetCookie(w, &http.Cookie{Name: "session", Value: "fixture"})
			w.WriteHeader(204)
		case "/api/v1/auth/session":
			_, _ = w.Write([]byte(`{"authenticated":true,"account_id":"fixture"}`))
		case "/api/v1/realtime":
			conn, err := websocket.Accept(w, r, nil)
			if err != nil {
				return
			}
			defer conn.CloseNow()
			for _, frame := range []string{
				`{"kind":"connection.ready","payload":{}}`,
				`{"kind":"maintenance.snapshot","payload":{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":1,"active":false}}`,
				`{"kind":"voice.roster.snapshot","payload":{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":1,"observed_at":"2026-11-09T00:00:00Z","channels":[]}}`,
			} {
				if conn.Write(ctx, websocket.MessageText, []byte(frame)) != nil {
					return
				}
			}
			<-ctx.Done()
		default:
			t.Error("unexpected fixture route")
		}
	}))
	defer server.Close()
	client := server.Client()
	client.Jar, _ = cookiejar.New(nil)
	manifest := validate_target.Manifest{Origin: server.URL, Accounts: []validate_target.Account{{Login: "qa_load_000", Password: "fixture", ID: "fixture"}}}
	measure := NewMeasurements(1)
	actor, err := StartActor(ctx, client, manifest, 0, false, measure)
	if err != nil {
		t.Fatal(err)
	}
	for !measure.Complete() && ctx.Err() == nil {
		time.Sleep(10 * time.Millisecond)
	}
	actor.Close()
	if !measure.Complete() {
		t.Fatal("missing initial domain")
	}
	cancel()
}
