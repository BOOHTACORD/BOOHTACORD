package connectsession

import (
	"context"
	"crypto/sha256"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestRevokedSessionClosesEvenWhenSocketWriterIsBlocked(t *testing.T) {
	var revoked atomic.Bool
	checked := make(chan struct{}, 1)
	principal := auth.Principal{AccountID: "member", SessionDigest: sha256.Sum256([]byte("session"))}
	authenticator := authenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		if revoked.Load() {
			select {
			case checked <- struct{}{}:
			default:
			}
			return auth.Principal{}, auth.ErrUnauthenticated
		}
		return principal, nil
	})
	hub := eventhub.New(8)
	handler := NewHandlerWithEvents(authenticator, 20*time.Millisecond, time.Now, nil, nil, hub)
	done := make(chan struct{})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer close(done)
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 9*time.Second)
	defer cancel()
	socket, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=opaque"}}})
	if err != nil {
		t.Fatal(err)
	}
	defer socket.CloseNow()
	for i := 0; i < 3; i++ {
		var event Event
		if err := wsjson.Read(ctx, socket, &event); err != nil {
			t.Fatal(err)
		}
	}
	hub.Publish(eventhub.Event{EventID: "synthetic", Kind: "channel.updated", Payload: map[string]any{"padding": strings.Repeat("x", 16<<20)}})
	time.Sleep(100 * time.Millisecond)
	revoked.Store(true)
	select {
	case <-checked:
	case <-time.After(time.Second):
		t.Fatal("blocked writer delayed the session check")
	}
	select {
	case <-done:
	case <-time.After(6500 * time.Millisecond):
		t.Fatal("blocked writer delayed session revocation")
	}
}

func TestSessionStoreOutageDoesNotClaimRevocation(t *testing.T) {
	principal := auth.Principal{AccountID: "member", SessionDigest: sha256.Sum256([]byte("session"))}
	authenticator := authenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		return auth.Principal{}, context.DeadlineExceeded
	})
	handler := NewHandler(authenticator, 10*time.Millisecond, time.Now, nil, nil)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	socket, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=opaque"}}})
	if err != nil {
		t.Fatal(err)
	}
	defer socket.CloseNow()
	var event Event
	if err := wsjson.Read(ctx, socket, &event); err != nil {
		t.Fatal(err)
	}
	err = wsjson.Read(ctx, socket, &event)
	if websocket.CloseStatus(err) != websocket.StatusTryAgainLater {
		t.Fatalf("outage close status = %v", websocket.CloseStatus(err))
	}
}
