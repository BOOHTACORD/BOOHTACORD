package connectsession

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

func TestRosterSocketBoundsWholeFrameAndHidesLease(t *testing.T) {
	for _, name := range []string{"normal", strings.Repeat("x", 8192)} {
		stream := &socketRoster{deliveries: make(chan prepared.Delivery, 1)}
		stream.current.Store(true)
		principal := auth.Principal{AccountID: "member", SessionDigest: sha256.Sum256([]byte("session"))}
		factory := func(context.Context, auth.Principal, *http.Cookie) (RosterStream, error) { return stream, nil }
		authenticator := authenticatorFunc(func(context.Context, string) (auth.Principal, error) { return principal, nil })
		handler := NewHandlerWithRoster(authenticator, 0, time.Now, nil, nil, nil, nil, nil, factory, 1024)
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
		}))
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"?capabilities=voice_roster_v1", &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=opaque"}}})
		if err != nil {
			t.Fatal(err)
		}
		_ = readMaintenanceEvent(t, ws)
		state := coordinator.State{Generation: "4dc94622-3f0c-46e6-a293-83395b287fcc", Revision: 1, ObservedAt: time.Now().UTC(), Roster: roster.Result{Channels: []roster.ChannelRoster{{ChannelID: "channel", Participants: []roster.Participant{{LeaseID: "secret-lease", DisplayName: name}}}}}}
		stream.deliveries <- prepared.Delivery{State: state}
		_, frame, err := ws.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		var event Event
		if err := json.Unmarshal(frame, &event); err != nil {
			t.Fatal(err)
		}
		if len(frame) > 1024 || strings.Contains(string(frame), "secret-lease") {
			t.Fatal("oversized frame or internal lease leaked")
		}
		want := "voice.roster.snapshot"
		if len(name) > 1024 {
			want = "voice.roster.unavailable"
		}
		if event.Kind != want {
			t.Fatalf("got %s, want %s", event.Kind, want)
		}
		_ = ws.CloseNow()
		cancel()
		server.Close()
	}
}

func TestRosterSocketSessionInvalidUsesPolicyClose(t *testing.T) {
	stream := &socketRoster{deliveries: make(chan prepared.Delivery, 1)}
	principal := auth.Principal{AccountID: "member"}
	factory := func(context.Context, auth.Principal, *http.Cookie) (RosterStream, error) { return stream, nil }
	handler := NewHandlerWithRoster(nil, 0, time.Now, nil, nil, nil, nil, nil, factory, 1024)
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
	_ = readMaintenanceEvent(t, ws)
	stream.deliveries <- prepared.Delivery{SessionInvalid: true}
	var event Event
	if err := wsjson.Read(ctx, ws, &event); websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
		t.Fatalf("invalid session: %v", err)
	}
}
