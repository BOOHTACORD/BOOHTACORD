package connectsession

import (
	"context"
	"crypto/sha256"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestSessionMonitorRejectsDifferentSessionIdentity(t *testing.T) {
	original := auth.Principal{AccountID: "member", SessionDigest: sha256.Sum256([]byte("original"))}
	for _, changed := range []auth.Principal{
		{AccountID: "other", SessionDigest: original.SessionDigest},
		{AccountID: original.AccountID, SessionDigest: sha256.Sum256([]byte("other"))},
	} {
		authenticator := authenticatorFunc(func(context.Context, string) (auth.Principal, error) { return changed, nil })
		handler := NewHandler(authenticator, 10*time.Millisecond, time.Now, nil, nil)
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), original)))
		}))
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		socket, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=opaque"}}})
		if err != nil {
			cancel()
			server.Close()
			t.Fatal(err)
		}
		var event Event
		err = wsjson.Read(ctx, socket, &event)
		if err == nil {
			err = wsjson.Read(ctx, socket, &event)
		}
		_ = socket.CloseNow()
		cancel()
		server.Close()
		if websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
			t.Fatalf("identity mismatch close status = %v", websocket.CloseStatus(err))
		}
	}
}
