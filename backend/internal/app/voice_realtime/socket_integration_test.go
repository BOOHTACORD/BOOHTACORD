package voicerealtime

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	connect "voice-platform/backend/internal/realtime/connect_session"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	watch "voice-platform/backend/internal/voice/watch_connected_participants"
)

type sessionFunc func(context.Context, string) (auth.Principal, error)

func (f sessionFunc) Authenticate(ctx context.Context, token string) (auth.Principal, error) {
	return f(ctx, token)
}

func TestLiveSocketUsesSharedGuardedRosterAndStops(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	principal := auth.Principal{AccountID: account}
	guard := guardFunc(func(_ context.Context, token string, who auth.Principal, snapshot roster.Result) error {
		if token != "opaque" || who.AccountID != account || snapshot.Channels[0].ChannelID != account {
			t.Error("recipient scope was not preserved")
		}
		return nil
	})
	config := coordinator.Config{Workers: 1, MaxAccounts: 1, MaxSubscribers: 1, MaxSnapshotBytes: 4096, PollInterval: time.Hour, ReadTimeout: time.Second}
	factory, stop, err := Start(ctx, config, &lister{}, guard, watch.NewNotifier())
	if err != nil {
		t.Fatal(err)
	}
	authenticator := sessionFunc(func(context.Context, string) (auth.Principal, error) { return principal, nil })
	handler := connect.NewHandlerWithRoster(authenticator, 0, time.Now, nil, nil, nil, nil, nil, factory.Open, 4096)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
	}))
	defer server.Close()
	ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"?capabilities=voice_roster_v1", &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=opaque"}}})
	if err != nil {
		t.Fatal(err)
	}
	defer ws.CloseNow()
	read, finish := context.WithTimeout(ctx, 2*time.Second)
	defer finish()
	var event connect.Event
	if err := wsjson.Read(read, ws, &event); err != nil || event.Kind != "connection.ready" {
		t.Fatalf("ready: %v", err)
	}
	if err := wsjson.Read(read, ws, &event); err != nil || event.Kind != "voice.roster.snapshot" {
		t.Fatalf("roster: %v %s", err, event.Kind)
	}
	shutdown, end := context.WithTimeout(context.Background(), time.Second)
	defer end()
	if err := stop(shutdown); err != nil {
		t.Fatal(err)
	}
	if err := wsjson.Read(read, ws, &event); err == nil {
		t.Fatal("socket survived coordinator shutdown")
	}
}
