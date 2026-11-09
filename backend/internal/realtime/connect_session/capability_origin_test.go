package connectsession

import (
	"context"
	"github.com/coder/websocket"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestRejectedOriginDoesNotCountCapabilityConnection(t *testing.T) {
	obs := capabilityObserver{make(chan string, 1), make(chan string, 1)}
	handler := NewHandler(nil, 0, nil, nil, obs)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "synthetic"})))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	conn, response, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"?capabilities=voice_roster_v1,maintenance_v1", &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {"https://example.invalid"}}})
	if conn != nil {
		conn.CloseNow()
	}
	if err == nil || response == nil || response.StatusCode != http.StatusForbidden {
		t.Fatalf("origin accepted: %v", err)
	}
	select {
	case value := <-obs.opened:
		t.Fatalf("rejected origin counted: %s", value)
	default:
	}
}
