package connectsession

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type capabilityObserver struct{ opened, closed chan string }

func (capabilityObserver) RealtimeConnectionOpened()                    {}
func (capabilityObserver) RealtimeConnectionClosed()                    {}
func (capabilityObserver) ObserveRealtimeConnectionReady(time.Duration) {}
func (o capabilityObserver) RealtimeCapabilityOpened(v string)          { o.opened <- v }
func (o capabilityObserver) RealtimeCapabilityClosed(v string)          { o.closed <- v }

func TestAcceptedCapabilitiesAreCountedAndReleasedWithoutRawLabels(t *testing.T) {
	for _, tc := range []struct{ query, want string }{
		{"", "neither"},
		{"?capabilities=voice_roster_v1", "roster_only"},
		{"?capabilities=maintenance_v1", "maintenance_only"},
		{"?capabilities=voice_roster_v1,maintenance_v1,user-secret", "both"},
	} {
		t.Run(tc.want, func(t *testing.T) {
			obs := capabilityObserver{make(chan string, 1), make(chan string, 1)}
			handler := NewHandler(nil, 0, nil, nil, obs)
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "synthetic"})))
			}))
			defer server.Close()
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			socket, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+tc.query, nil)
			if err != nil {
				t.Fatal(err)
			}
			defer socket.CloseNow()
			select {
			case got := <-obs.opened:
				if got != tc.want {
					t.Fatalf("open: %s", got)
				}
			case <-ctx.Done():
				t.Fatal("not observed")
			}
			socket.CloseNow()
			select {
			case got := <-obs.closed:
				if got != tc.want {
					t.Fatalf("close: %s", got)
				}
			case <-ctx.Done():
				t.Fatal("not released")
			}
		})
	}
}
