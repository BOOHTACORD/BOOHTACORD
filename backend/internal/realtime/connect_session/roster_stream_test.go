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
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

type socketRoster struct {
	deliveries chan prepared.Delivery
	current    atomic.Bool
	refreshes  atomic.Int32
	check      func(context.Context, coordinator.State) error
}

func (s *socketRoster) Events() <-chan prepared.Delivery { return s.deliveries }
func (s *socketRoster) Current(coordinator.State) bool   { return s.current.Load() }
func (s *socketRoster) RequestRefresh() bool             { s.refreshes.Add(1); return true }
func (s *socketRoster) Close()                           {}
func (s *socketRoster) WithRoster(ctx context.Context, _ coordinator.State, write func(context.Context) error) error {
	return write(ctx)
}

func (s *socketRoster) Check(ctx context.Context, state coordinator.State) error {
	if s.check == nil {
		return nil
	}
	return s.check(ctx, state)
}

func TestRosterSocketNegotiatesAndSuppressesStaleDelivery(t *testing.T) {
	stream := &socketRoster{deliveries: make(chan prepared.Delivery, 2)}
	var calls atomic.Int32
	factory := func(context.Context, auth.Principal, *http.Cookie) (RosterStream, error) {
		calls.Add(1)
		return stream, nil
	}
	principal := auth.Principal{AccountID: "member", SessionDigest: sha256.Sum256([]byte("session"))}
	authenticator := authenticatorFunc(func(context.Context, string) (auth.Principal, error) { return principal, nil })
	handler := NewHandlerWithRoster(authenticator, 0, time.Now, nil, nil, nil, nil, nil, factory, 4096)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	dial := func(query string) *websocket.Conn {
		ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+query, &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=opaque"}}})
		if err != nil {
			t.Fatal(err)
		}
		if event := readMaintenanceEvent(t, ws); event.Kind != "connection.ready" {
			t.Fatal(event.Kind)
		}
		return ws
	}
	legacy := dial("")
	defer legacy.CloseNow()
	if calls.Load() != 0 {
		t.Fatal("legacy client subscribed")
	}
	ws := dial("?capabilities=voice_roster_v1")
	defer ws.CloseNow()
	if calls.Load() != 1 {
		t.Fatal("negotiated subscription missing")
	}
	state := coordinator.State{Generation: "4dc94622-3f0c-46e6-a293-83395b287fcc", Revision: 1, ObservedAt: time.Now().UTC(), Roster: roster.Result{Channels: []roster.ChannelRoster{}}}
	stream.deliveries <- prepared.Delivery{State: state}
	deadline := time.Now().Add(time.Second)
	for stream.refreshes.Load() == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if stream.refreshes.Load() == 0 {
		t.Fatal("stale proof was not refreshed")
	}
	stream.current.Store(true)
	stream.deliveries <- prepared.Delivery{State: state}
	if event := readMaintenanceEvent(t, ws); event.Kind != "voice.roster.snapshot" {
		t.Fatalf("stale frame delivered: %s", event.Kind)
	}
	stream.deliveries <- prepared.Delivery{Unavailable: true}
	if event := readMaintenanceEvent(t, ws); event.Kind != "voice.roster.unavailable" || event.Payload["code"] != "temporarily_unavailable" {
		t.Fatalf("unexpected unavailable: %+v", event)
	}
}
