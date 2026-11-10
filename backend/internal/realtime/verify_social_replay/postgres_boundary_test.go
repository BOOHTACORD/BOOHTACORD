package verifysocialreplay

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"github.com/google/uuid"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	connect "voice-platform/backend/internal/realtime/connect_session"
	hub "voice-platform/backend/internal/realtime/event_hub"
	replay "voice-platform/backend/internal/realtime/replay_event/postgres"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestPostgresSocketRequiresResyncAtOverflowAndNewEpoch(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	db := postgresfixture.New(t, ctx, "TEST_DATABASE_URL", postgresfixture.LoopbackOrLocalhost)
	for _, migration := range []string{"0036_create_realtime_events.sql", "0047_add_trace_causality.sql"} {
		if strings.HasPrefix(migration, "0047") {
			if _, err := db.Exec(ctx, `CREATE TABLE voice_sfu_revocations(lease_id uuid PRIMARY KEY)`); err != nil {
				t.Fatal(err)
			}
		}
		content, err := os.ReadFile("../../database/migrate/migrations/" + migration)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := db.Exec(ctx, string(content)); err != nil {
			t.Fatal(err)
		}
	}
	journal := replay.New(db)
	firstHub := hub.New(8)
	firstHub.SetJournal(journal)
	cursor := uuid.NewString()
	for index := 0; index <= replay.ReplayLimit+1; index++ {
		id := uuid.NewString()
		if index == 0 {
			id = cursor
		}
		event := hub.Event{EventID: id, Kind: "channel.updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"revision": index + 1}}
		if err := journal.Append(ctx, event, nil, firstHub.BootEpoch()); err != nil {
			t.Fatalf("append %d: %v", index, err)
		}
	}
	secondHub := hub.New(8)
	secondHub.SetJournal(journal)
	for _, test := range []struct {
		name, reason string
		hub          *hub.Hub
	}{{"overflow", "replay_limit", firstHub}, {"new epoch", "server_restart", secondHub}} {
		t.Run(test.name, func(t *testing.T) {
			principal := auth.Principal{AccountID: uuid.NewString()}
			handler := connect.NewHandlerWithEvents(authenticatorFunc(func(context.Context, string) (auth.Principal, error) { return principal, nil }), time.Hour, time.Now, nil, nil, test.hub)
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), principal)))
			}))
			defer server.Close()
			target := "ws" + strings.TrimPrefix(server.URL, "http") + "?after=" + cursor
			conn, _, err := websocket.Dial(ctx, target, &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}, "Cookie": {"vp_session=opaque"}}})
			if err != nil {
				t.Fatal(err)
			}
			defer conn.CloseNow()
			var event hub.Event
			if err := wsjson.Read(ctx, conn, &event); err != nil || event.Kind != "connection.resync_required" || event.Payload["reason"] != test.reason {
				t.Fatalf("expected resync reason %q; kind=%q error=%v", test.reason, event.Kind, err)
			}
		})
	}
}
