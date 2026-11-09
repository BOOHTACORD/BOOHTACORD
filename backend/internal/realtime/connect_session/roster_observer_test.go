package connectsession

import (
	"context"
	"github.com/coder/websocket"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

type observedRoster struct {
	*socketRoster
	unavailable atomic.Int32
}

func (s *observedRoster) ObserveRosterUnavailable(_ time.Duration, sent bool) {
	if sent {
		s.unavailable.Add(1)
	}
}

func TestUnavailableRosterFrameIsObservedOnlyAfterWrite(t *testing.T) {
	s := &observedRoster{socketRoster: &socketRoster{deliveries: make(chan prepared.Delivery, 1)}}
	principal := auth.Principal{AccountID: "member"}
	factory := func(context.Context, auth.Principal, *http.Cookie) (RosterStream, error) { return s, nil }
	handler := NewHandlerWithRoster(nil, 0, time.Now, nil, nil, nil, nil, nil, factory, 4096)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"?capabilities=voice_roster_v1", &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=opaque"}}})
	if err != nil {
		t.Fatal(err)
	}
	defer ws.CloseNow()
	_ = readMaintenanceEvent(t, ws)
	s.deliveries <- prepared.Delivery{Unavailable: true}
	if event := readMaintenanceEvent(t, ws); event.Kind != "voice.roster.unavailable" {
		t.Fatal(event.Kind)
	}
	deadline := time.Now().Add(time.Second)
	for s.unavailable.Load() == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if s.unavailable.Load() != 1 {
		t.Fatal("unavailable frame was not observed")
	}
}
