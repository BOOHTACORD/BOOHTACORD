package runrostermatrix

import (
	"context"
	"github.com/coder/websocket"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	chat "voice-platform/backend/internal/load/matrix_chat"
	"voice-platform/backend/internal/load/validate_target"
)

func TestActorRecordsMessageOnItsExistingSocket(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	send := make(chan struct{})
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
			select {
			case <-send:
			case <-ctx.Done():
				return
			}
			_ = conn.Write(ctx, websocket.MessageText, []byte(`{"kind":"presence.changed","payload":{"presence":"online"}}`))
			_ = conn.Write(ctx, websocket.MessageText, []byte(strings.Replace(`{"kind":"message.created","occurred_at":"TIME","payload":{"message_id":"11111111-1111-4111-8111-111111111111"}}`, "TIME", time.Now().UTC().Format(time.RFC3339Nano), 1)))
			<-ctx.Done()
		default:
			t.Error("unexpected route")
		}
	}))
	defer server.Close()
	client := server.Client()
	client.Jar, _ = cookiejar.New(nil)
	manifest := validate_target.Manifest{Origin: server.URL, Accounts: []validate_target.Account{{Login: "qa_load_000", Password: "fixture", ID: "fixture"}}}
	measure := NewMeasurements(1)
	messages, err := chat.New(1)
	if err != nil {
		t.Fatal(err)
	}
	actor, err := StartActorWithMessages(ctx, client, manifest, 0, false, measure, messages)
	if err != nil {
		t.Fatal(err)
	}
	defer actor.Close()
	if err := messages.Begin(time.Now()); err != nil {
		t.Fatal(err)
	}
	close(send)
	samples, duplicates, err := messages.Finish(ctx, "11111111-1111-4111-8111-111111111111")
	if err != nil || len(samples) != 1 || duplicates != 0 || messages.PresenceCount() != 1 {
		t.Fatalf("message observation: %v %d %v", samples, duplicates, err)
	}
}
