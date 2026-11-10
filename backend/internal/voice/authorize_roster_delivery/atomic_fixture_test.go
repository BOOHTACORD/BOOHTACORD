package authorizerosterdelivery

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionpostgres "voice-platform/backend/internal/identity/authenticate_session/postgres"
	"voice-platform/backend/internal/identity/serialize_session_delivery"
	"voice-platform/backend/internal/identity/session"
	pgfixture "voice-platform/backend/internal/testsupport/postgres"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	rosterpostgres "voice-platform/backend/internal/voice/list_connected_participants/postgres"
)

type atomicFixture struct {
	pool                *pgxpool.Pool
	guard               Guard
	principal           auth.Principal
	snapshot            roster.Result
	member, room, lease string
	memberDigest        []byte
}

func newAtomicFixture(t *testing.T, ctx context.Context) atomicFixture {
	t.Helper()
	pool := pgfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", pgfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	actor, member, category, room, lease := uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString()
	a, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	m, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	for _, user := range []struct{ id, login string }{{actor, "atomic_actor"}, {member, "atomic_member"}} {
		if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,$2,'test','MEMBER')`, user.id, user.login); err != nil {
			t.Fatal(err)
		}
	}
	statements := []struct {
		query string
		args  []any
	}{
		{`INSERT INTO sessions(token_digest,user_id) VALUES($1,$2),($3,$4)`, []any{a.Digest[:], actor, m.Digest[:], member}},
		{`INSERT INTO categories(id,name,position) VALUES($1,'QA',0)`, []any{category}},
		{`INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$2,'Voice','VOICE',0)`, []any{room, category}},
		{`INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest) VALUES($1,$2,$3,$4)`, []any{lease, member, room, m.Digest[:]}},
	}
	for _, statement := range statements {
		if _, err := pool.Exec(ctx, statement.query, statement.args...); err != nil {
			t.Fatal(err)
		}
	}
	sessionGuard, err := serializesessiondelivery.New(pool, 2, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	repository := rosterpostgres.New(rosterpostgres.NewPoolDatabase(pool))
	authenticator := auth.New(sessionpostgres.New(sessionpostgres.NewPoolDatabase(pool)))
	principal, err := authenticator.Authenticate(ctx, a.Token)
	if err != nil {
		t.Fatal(err)
	}
	snapshot := roster.Result{Channels: []roster.ChannelRoster{{ChannelID: room, Participants: []roster.Participant{{LeaseID: lease, AccountID: member, DisplayName: "atomic_member"}}}}}
	return atomicFixture{pool, New(authenticator, repository, sessionGuard), principal, snapshot, member, room, lease, m.Digest[:]}
}
