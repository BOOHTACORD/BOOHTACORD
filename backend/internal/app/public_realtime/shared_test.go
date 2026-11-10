package publicrealtime

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
	connectsession "voice-platform/backend/internal/realtime/connect_session"
)

type sharedReader struct{ active atomic.Bool }

func (r *sharedReader) Active(context.Context) (bool, error) { return r.active.Load(), nil }

func TestPublicAndAuthenticatedSocketsShareMaintenanceState(t *testing.T) {
	reader := &sharedReader{}
	public, observer, stop, err := StartShared(context.Background(), reader, "https://example.test", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer stop(context.Background())
	authenticated := connectsession.NewHandlerWithMaintenance(nil, 0, nil, nil, nil, nil, nil, observer)
	mux := http.NewServeMux()
	mux.Handle("/public", public)
	mux.HandleFunc("/auth", func(w http.ResponseWriter, r *http.Request) {
		authenticated.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "member"})))
	})
	server := httptest.NewServer(mux)
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	base := "ws" + strings.TrimPrefix(server.URL, "http")
	guest, _, err := websocket.Dial(ctx, base+"/public", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer guest.CloseNow()
	member, _, err := websocket.Dial(ctx, base+"/auth?capabilities=maintenance_v1", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer member.CloseNow()
	type frame struct {
		Kind    string         `json:"kind"`
		Payload map[string]any `json:"payload"`
	}
	read := func(socket *websocket.Conn) frame {
		var f frame
		if err := wsjson.Read(ctx, socket, &f); err != nil {
			t.Fatal(err)
		}
		return f
	}
	if read(guest).Kind != "connection.ready" || read(member).Kind != "connection.ready" {
		t.Fatal("missing ready")
	}
	one, two := read(guest), read(member)
	if one.Kind != "maintenance.snapshot" || two.Kind != "maintenance.snapshot" || one.Payload["generation"] != two.Payload["generation"] {
		t.Fatalf("snapshots: %+v %+v", one, two)
	}
	reader.active.Store(true)
	observer.RequestRefresh()
	one, two = read(guest), read(member)
	if one.Kind != "maintenance.changed" || two.Kind != "maintenance.changed" || one.Payload["active"] != true || two.Payload["active"] != true || one.Payload["revision"] != two.Payload["revision"] {
		t.Fatalf("changes: %+v %+v", one, two)
	}
}
