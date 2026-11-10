package connectsession

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
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

func TestPostgresRevocationBeforeRosterWriteDoesNotLeak(t *testing.T) {
	for _, kind := range []string{"actor_session", "actor_role", "actor_support", "participant_session", "participant_expiry", "participant_ban", "participant_rename", "lease", "channel_archive"} {
		t.Run(kind, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			f := newPostgresRaceFixture(t, ctx)
			query, arg := `UPDATE sessions SET revoked_at=now() WHERE token_digest=$1`, any(f.actorDigest)
			switch kind {
			case "actor_role":
				query, arg = `UPDATE users SET role='ADMINISTRATOR' WHERE id=$1`, f.stream.principal.AccountID
			case "actor_support":
				query, arg = `UPDATE support_product_identity SET account_id=$1 WHERE singleton=true`, f.stream.principal.AccountID
			case "participant_session":
				arg = f.memberDigest
			case "participant_expiry":
				query, arg = `UPDATE sessions SET expires_at=now()-interval '1 second' WHERE token_digest=$1`, f.memberDigest
			case "participant_ban":
				query, arg = `UPDATE users SET blocked_at=now() WHERE id=$1`, f.member
			case "participant_rename":
				query, arg = `UPDATE users SET display_name='renamed' WHERE id=$1`, f.member
			case "lease":
				query, arg = `UPDATE voice_leases SET revoked_at=now(),revocation_reason='KICK' WHERE id=$1`, f.lease
			case "channel_archive":
				query, arg = `UPDATE channels SET archived_at=now() WHERE id=$1`, f.room
			}
			f.stream.mutate = func() error { _, err := f.pool.Exec(ctx, query, arg); return err }
			factory := func(context.Context, auth.Principal, *http.Cookie) (RosterStream, error) { return f.stream, nil }
			handler := NewHandlerWithRoster(f.authenticator, 0, time.Now, nil, nil, nil, nil, nil, factory, 4096)
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), f.stream.principal)))
			}))
			defer server.Close()
			ws, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"?capabilities=voice_roster_v1", &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": {"vp_session=" + f.stream.token}}})
			if err != nil {
				t.Fatal(err)
			}
			defer ws.CloseNow()
			var event Event
			if err := wsjson.Read(ctx, ws, &event); err != nil || event.Kind != "connection.ready" {
				t.Fatalf("ready: %v %s", err, event.Kind)
			}
			f.stream.deliveries <- prepared.Delivery{State: f.state}
			select {
			case err := <-f.stream.mutated:
				if err != nil {
					t.Fatal(err)
				}
			case <-ctx.Done():
				t.Fatal("mutation did not reach delivery boundary")
			}
			read, stop := context.WithTimeout(ctx, 1500*time.Millisecond)
			defer stop()
			err = wsjson.Read(read, ws, &event)
			if kind == "actor_session" || kind == "actor_role" || kind == "actor_support" {
				if websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
					t.Fatalf("revoked actor did not receive policy close: %v", err)
				}
			} else if err == nil || read.Err() != context.DeadlineExceeded || f.stream.refreshes.Load() == 0 {
				t.Fatalf("stale roster was not suppressed and refreshed: kind=%s err=%v refreshes=%d", event.Kind, err, f.stream.refreshes.Load())
			}
		})
	}
}
