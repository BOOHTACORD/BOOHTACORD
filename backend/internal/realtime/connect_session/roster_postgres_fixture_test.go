package connectsession

import (
	"context"
	"sync"
	"sync/atomic"
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
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	rosterpostgres "voice-platform/backend/internal/voice/list_connected_participants/postgres"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

type postgresRaceRoster struct {
	*socketRoster
	guard     guard.Guard
	principal auth.Principal
	token     string
	checked   atomic.Bool
	once      sync.Once
	mutate    func() error
	mutated   chan error
}

func (s *postgresRaceRoster) Check(ctx context.Context, state coordinator.State) error {
	err := s.guard.Check(ctx, s.token, s.principal, state.Roster)
	if err == nil {
		s.checked.Store(true)
	}
	return err
}
func (s *postgresRaceRoster) Current(coordinator.State) bool {
	if s.checked.Load() {
		s.once.Do(func() { s.mutated <- s.mutate() })
	}
	return true
}
func (s *postgresRaceRoster) WithRoster(ctx context.Context, state coordinator.State, write func(context.Context) error) error {
	return s.guard.WithRoster(ctx, s.principal, state.Roster, write)
}

type postgresRaceFixture struct {
	pool                      *pgxpool.Pool
	stream                    *postgresRaceRoster
	authenticator             auth.Service
	state                     coordinator.State
	actorDigest, memberDigest []byte
	member, room, lease       string
}

func newPostgresRaceFixture(t *testing.T, ctx context.Context) postgresRaceFixture {
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
	for _, u := range []struct{ id, login string }{{actor, "socket_actor"}, {member, "socket_member"}} {
		if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,$2,'x','MEMBER')`, u.id, u.login); err != nil {
			t.Fatal(err)
		}
	}
	statements := []struct {
		sql  string
		args []any
	}{
		{`INSERT INTO sessions(token_digest,user_id) VALUES($1,$2),($3,$4)`, []any{a.Digest[:], actor, m.Digest[:], member}},
		{`INSERT INTO categories(id,name,position) VALUES($1,'QA',0)`, []any{category}},
		{`INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$2,'Voice','VOICE',0)`, []any{room, category}},
		{`INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest) VALUES($1,$2,$3,$4)`, []any{lease, member, room, m.Digest[:]}},
	}
	for _, statement := range statements {
		if _, err := pool.Exec(ctx, statement.sql, statement.args...); err != nil {
			t.Fatal(err)
		}
	}
	authenticator := auth.New(sessionpostgres.New(sessionpostgres.NewPoolDatabase(pool)))
	principal, err := authenticator.Authenticate(ctx, a.Token)
	if err != nil {
		t.Fatal(err)
	}
	delivery, err := serializesessiondelivery.New(pool, 4, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	repository := rosterpostgres.New(rosterpostgres.NewPoolDatabase(pool))
	s := &postgresRaceRoster{socketRoster: &socketRoster{deliveries: make(chan prepared.Delivery, 1)}, guard: guard.New(authenticator, repository, delivery), principal: principal, token: a.Token, mutated: make(chan error, 1)}
	state := coordinator.State{Generation: uuid.NewString(), Revision: 1, ObservedAt: time.Now().UTC(), Roster: roster.Result{Channels: []roster.ChannelRoster{{ChannelID: room, Participants: []roster.Participant{{LeaseID: lease, AccountID: member, DisplayName: "socket_member"}}}}}}
	return postgresRaceFixture{pool, s, authenticator, state, a.Digest[:], m.Digest[:], member, room, lease}
}
