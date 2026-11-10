package connectsession

import (
	"context"
	"crypto/sha256"
	"errors"
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
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

type revokeWindowStream struct {
	*socketRoster
	checked atomic.Bool
	revoked atomic.Bool
}

func (s *revokeWindowStream) Check(context.Context, coordinator.State) error {
	s.checked.Store(true)
	return nil
}
func (s *revokeWindowStream) Current(coordinator.State) bool {
	if s.checked.Load() {
		s.revoked.Store(true)
	}
	return true
}

func (s *revokeWindowStream) WithRoster(ctx context.Context, _ coordinator.State, write func(context.Context) error) error {
	if s.revoked.Load() {
		return guard.ErrSession
	}
	return write(ctx)
}

// Revoke after authorization has completed but before the roster frame is written.
func TestRosterNotSentAfterSessionRevokedAtFinalBoundary(t *testing.T) {
	s := &revokeWindowStream{socketRoster: &socketRoster{deliveries: make(chan prepared.Delivery, 1)}}
	principal := auth.Principal{AccountID: "member", SessionDigest: sha256.Sum256([]byte("probe-session"))}
	authenticate := authenticatorFunc(func(context.Context, string) (auth.Principal, error) {
		if s.revoked.Load() {
			return auth.Principal{}, errors.New("revoked")
		}
		return principal, nil
	})
	factory := func(context.Context, auth.Principal, *http.Cookie) (RosterStream, error) { return s, nil }
	handler := NewHandlerWithRoster(authenticate, 0, time.Now, nil, nil, nil, nil, nil, factory, 4096)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"?capabilities=voice_roster_v1", &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=probe"}}})
	if err != nil {
		t.Fatal(err)
	}
	defer ws.CloseNow()
	_ = readMaintenanceEvent(t, ws)
	state := coordinator.State{Generation: "4dc94622-3f0c-46e6-a293-83395b287fcc", Revision: 1, ObservedAt: time.Now().UTC(), Roster: roster.Result{Channels: []roster.ChannelRoster{{ChannelID: "11111111-1111-4111-8111-111111111111", Participants: []roster.Participant{}}}}}
	s.deliveries <- prepared.Delivery{State: state}
	var event Event
	err = wsjson.Read(ctx, ws, &event)
	if !s.revoked.Load() {
		t.Fatal("test did not reach the revocation boundary")
	}
	if err == nil && event.Kind == "voice.roster.snapshot" {
		t.Fatal("protected roster frame written after simulated revocation following final check")
	}
}
