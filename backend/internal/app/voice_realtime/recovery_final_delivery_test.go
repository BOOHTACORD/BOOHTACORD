package voicerealtime

import (
	"context"
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
	connect "voice-platform/backend/internal/realtime/connect_session"
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

type transientWriteGuard struct{ calls atomic.Int32 }

func (*transientWriteGuard) Check(context.Context, string, auth.Principal, roster.Result) error {
	return nil
}
func (g *transientWriteGuard) WithRoster(ctx context.Context, _ auth.Principal, _ roster.Result, write func(context.Context) error) error {
	if g.calls.Add(1) == 1 {
		return guard.ErrUnavailable
	}
	return write(ctx)
}

func TestUnchangedRosterRecoversAfterFinalGuardUnavailable(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	reader := &lister{}
	c, err := coordinator.New(coordinator.Config{Workers: 1, MaxAccounts: 1, MaxSubscribers: 1, MaxSnapshotBytes: 4096, PollInterval: 30 * time.Millisecond, ReadTimeout: time.Second}, reader, nil)
	if err != nil {
		t.Fatal(err)
	}
	go c.Run(ctx)
	pool, err := prepared.New(1, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	checker := &transientWriteGuard{}
	observer := &rosterObserver{}
	factory := New(c, pool, checker, observer)
	principal := auth.Principal{AccountID: account}
	handler := connect.NewHandlerWithRoster(nil, 0, time.Now, nil, nil, nil, nil, nil, factory.Open, 4096)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
	}))
	defer server.Close()
	read, end := context.WithTimeout(ctx, time.Second)
	defer end()
	ws, _, err := websocket.Dial(read, "ws"+strings.TrimPrefix(server.URL, "http")+"?capabilities=voice_roster_v1", &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=opaque"}}})
	if err != nil {
		t.Fatal(err)
	}
	defer ws.CloseNow()
	for _, kind := range []string{"connection.ready", "voice.roster.unavailable", "voice.roster.snapshot"} {
		var event connect.Event
		if err := wsjson.Read(read, ws, &event); err != nil {
			t.Fatalf("waiting for %s: %v (reads=%d checks=%d)", kind, err, reader.calls.Load(), checker.calls.Load())
		}
		if event.Kind != kind {
			t.Fatalf("expected %s, got %s", kind, event.Kind)
		}
	}
	deadline := time.Now().Add(time.Second)
	for observer.success.Load() == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if observer.initial.Load() != 1 || observer.unavailable.Load() != 1 || observer.success.Load() != 1 {
		t.Fatal("real socket outcomes were not observed")
	}
}
