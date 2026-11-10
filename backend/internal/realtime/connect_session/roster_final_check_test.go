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
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

func TestFinalRosterCheckDoesNotBlockEventsAndSuppressesRevokedSession(t *testing.T) {
	entered, release := make(chan struct{}), make(chan struct{})
	stream := &socketRoster{deliveries: make(chan prepared.Delivery, 1)}
	stream.current.Store(true)
	stream.check = func(ctx context.Context, _ coordinator.State) error {
		close(entered)
		select {
		case <-release:
			return guard.ErrSession
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	principal := auth.Principal{AccountID: "member", SessionDigest: sha256.Sum256([]byte("session"))}
	authenticator := authenticatorFunc(func(context.Context, string) (auth.Principal, error) { return principal, nil })
	factory := func(context.Context, auth.Principal, *http.Cookie) (RosterStream, error) { return stream, nil }
	hub := eventhub.New(8)
	handler := NewHandlerWithRoster(authenticator, 0, time.Now, nil, nil, hub, nil, nil, factory, 4096)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"?capabilities=voice_roster_v1", &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=opaque"}}})
	if err != nil {
		t.Fatal(err)
	}
	defer ws.CloseNow()
	for i := 0; i < 3; i++ {
		_ = readMaintenanceEvent(t, ws)
	}
	state := coordinator.State{Generation: "4dc94622-3f0c-46e6-a293-83395b287fcc", Revision: 1, ObservedAt: time.Now().UTC(), Roster: roster.Result{Channels: []roster.ChannelRoster{}}}
	stream.deliveries <- prepared.Delivery{State: state}
	select {
	case <-entered:
	case <-time.After(time.Second):
		t.Fatal("final authorization did not start")
	}
	hub.Publish(eventhub.Event{EventID: "priority", Kind: "channel.updated", Payload: map[string]any{}})
	if event := readMaintenanceEvent(t, ws); event.Kind != "channel.updated" {
		t.Fatalf("delayed event or leaked roster: %s", event.Kind)
	}
	close(release)
	var event Event
	if err := wsjson.Read(ctx, ws, &event); websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
		t.Fatalf("revocation did not close socket: %v", err)
	}
}
