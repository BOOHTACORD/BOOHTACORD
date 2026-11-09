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
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

func TestFinalRosterCheckHandlesStaleAndUnavailable(t *testing.T) {
	for _, failure := range []error{guard.ErrStale, guard.ErrUnavailable} {
		stream := &socketRoster{deliveries: make(chan prepared.Delivery, 1)}
		stream.current.Store(true)
		stream.check = func(context.Context, coordinator.State) error { return failure }
		principal := auth.Principal{AccountID: "member"}
		factory := func(context.Context, auth.Principal, *http.Cookie) (RosterStream, error) { return stream, nil }
		handler := NewHandlerWithRoster(nil, 0, time.Now, nil, nil, nil, nil, nil, factory, 4096)
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
		}))
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"?capabilities=voice_roster_v1", &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=opaque"}}})
		if err != nil {
			t.Fatal(err)
		}
		_ = readMaintenanceEvent(t, ws)
		state := coordinator.State{Generation: "4dc94622-3f0c-46e6-a293-83395b287fcc", Revision: 1, ObservedAt: time.Now().UTC(), Roster: roster.Result{Channels: []roster.ChannelRoster{}}}
		stream.deliveries <- prepared.Delivery{State: state}
		if failure == guard.ErrStale {
			deadline := time.Now().Add(time.Second)
			for stream.refreshes.Load() == 0 && time.Now().Before(deadline) {
				time.Sleep(time.Millisecond)
			}
			if stream.refreshes.Load() == 0 {
				t.Fatal("stale check did not refresh")
			}
			stream.deliveries <- prepared.Delivery{Unavailable: true}
		}
		if event := readMaintenanceEvent(t, ws); event.Kind != "voice.roster.unavailable" {
			t.Fatalf("failure leaked snapshot: %s", event.Kind)
		}
		_ = ws.CloseNow()
		cancel()
		server.Close()
	}
}
