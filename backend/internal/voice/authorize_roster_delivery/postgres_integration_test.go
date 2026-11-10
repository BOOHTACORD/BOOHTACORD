package authorizerosterdelivery

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"voice-platform/backend/internal/database/migrate"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionpostgres "voice-platform/backend/internal/identity/authenticate_session/postgres"
	"voice-platform/backend/internal/identity/session"
	pgfixture "voice-platform/backend/internal/testsupport/postgres"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	rosterpostgres "voice-platform/backend/internal/voice/list_connected_participants/postgres"
)

func TestPostgresGuardRejectsRevokedLeaseAndSession(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := pgfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", pgfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	actorID, memberID, categoryID, roomID, leaseID := uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString()
	actorToken, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	memberToken, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	for _, user := range []struct{ id, login string }{{actorID, "guard_actor"}, {memberID, "guard_member"}} {
		if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,$2,'test','MEMBER')`, user.id, user.login); err != nil {
			t.Fatal(err)
		}
	}
	for _, statement := range []struct {
		query string
		args  []any
	}{
		{`INSERT INTO sessions(token_digest,user_id) VALUES($1,$2),($3,$4)`, []any{actorToken.Digest[:], actorID, memberToken.Digest[:], memberID}},
		{`INSERT INTO categories(id,name,position) VALUES($1,'QA',0)`, []any{categoryID}},
		{`INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$2,'Voice','VOICE',0)`, []any{roomID, categoryID}},
		{`INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest) VALUES($1,$2,$3,$4)`, []any{leaseID, memberID, roomID, memberToken.Digest[:]}},
	} {
		if _, err := pool.Exec(ctx, statement.query, statement.args...); err != nil {
			t.Fatal(err)
		}
	}
	authenticator := auth.New(sessionpostgres.New(sessionpostgres.NewPoolDatabase(pool)))
	principal, err := authenticator.Authenticate(ctx, actorToken.Token)
	if err != nil {
		t.Fatal(err)
	}
	guard := New(authenticator, rosterpostgres.New(rosterpostgres.NewPoolDatabase(pool)))
	snapshot := roster.Result{Channels: []roster.ChannelRoster{{ChannelID: roomID, Participants: []roster.Participant{{LeaseID: leaseID, AccountID: memberID, DisplayName: "guard_member"}}}}}
	if err := guard.Check(ctx, actorToken.Token, principal, snapshot); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `UPDATE voice_leases SET revoked_at=now(), revocation_reason='KICK' WHERE id=$1`, leaseID); err != nil {
		t.Fatal(err)
	}
	if err := guard.Check(ctx, actorToken.Token, principal, snapshot); !errors.Is(err, ErrStale) {
		t.Fatalf("revoked lease: %v", err)
	}
	if _, err := pool.Exec(ctx, `UPDATE sessions SET revoked_at=now() WHERE token_digest=$1`, actorToken.Digest[:]); err != nil {
		t.Fatal(err)
	}
	if err := guard.Check(ctx, actorToken.Token, principal, snapshot); !errors.Is(err, ErrSession) {
		t.Fatalf("revoked session: %v", err)
	}
}
