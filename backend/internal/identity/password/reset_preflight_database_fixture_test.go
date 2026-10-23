package password_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
	resetpostgres "voice-platform/backend/internal/identity/complete_password_reset/postgres"
	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/session"
	pgfixture "voice-platform/backend/internal/testsupport/postgres"
)

const preflightOldPassword = "synthetic original reset password"
const preflightNewPassword = "synthetic replacement reset password"

type resetPreflightFixture struct {
	pool                  *pgxpool.Pool
	repository            resetpostgres.Repository
	token                 session.Issued
	user, other, lease    string
	session, otherSession session.Issued
}

func newResetPreflightFixture(t *testing.T) resetPreflightFixture {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := pgfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", pgfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	token, err := session.Issue()
	if err != nil {
		t.Fatal("cannot prepare synthetic reset")
	}
	active, err := session.Issue()
	if err != nil {
		t.Fatal("cannot prepare synthetic session")
	}
	other, err := session.Issue()
	if err != nil {
		t.Fatal("cannot prepare synthetic session")
	}
	hash, err := password.Hash(ctx, preflightOldPassword)
	if err != nil {
		t.Fatal("cannot prepare native hash")
	}
	fixture := resetPreflightFixture{pool: pool, repository: resetpostgres.New(resetpostgres.NewPoolDatabase(pool)), token: token, user: uuid.NewString(), other: uuid.NewString(), lease: uuid.NewString(), session: active, otherSession: other}
	category, channel := uuid.NewString(), uuid.NewString()
	for _, seed := range []struct {
		sql  string
		args []any
	}{
		{`INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'preflightmember','Synthetic reset',$2,'MEMBER'),($3,'preflightother','Synthetic other',$2,'MEMBER')`, []any{fixture.user, hash, fixture.other}},
		{`INSERT INTO sessions(token_digest,user_id) VALUES($1,$2),($3,$4)`, []any{active.Digest[:], fixture.user, other.Digest[:], fixture.other}},
		{`INSERT INTO password_resets(token_digest,user_id,expires_at) VALUES($1,$2,now()+interval '1 hour')`, []any{token.Digest[:], fixture.user}},
		{`INSERT INTO categories(id,name,position) VALUES($1,'Synthetic category',0)`, []any{category}},
		{`INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$2,'Synthetic voice','VOICE',0)`, []any{channel, category}},
		{`INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest) VALUES($1,$2,$3,$4)`, []any{fixture.lease, fixture.user, channel, active.Digest[:]}},
	} {
		if _, err := pool.Exec(ctx, seed.sql, seed.args...); err != nil {
			t.Fatal(err)
		}
	}
	return fixture
}

type resetPreflightState struct {
	hash                                             string
	used, sessionRevoked, otherRevoked, leaseRevoked bool
	queue, audit                                     int
}

func (f resetPreflightFixture) state(t *testing.T) resetPreflightState {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var state resetPreflightState
	for _, check := range []struct {
		sql  string
		args []any
		dest []any
	}{
		{`SELECT password_hash FROM users WHERE id=$1`, []any{f.user}, []any{&state.hash}},
		{`SELECT used_at IS NOT NULL FROM password_resets WHERE token_digest=$1`, []any{f.token.Digest[:]}, []any{&state.used}},
		{`SELECT revoked_at IS NOT NULL FROM sessions WHERE token_digest=$1`, []any{f.session.Digest[:]}, []any{&state.sessionRevoked}},
		{`SELECT revoked_at IS NOT NULL FROM sessions WHERE token_digest=$1`, []any{f.otherSession.Digest[:]}, []any{&state.otherRevoked}},
		{`SELECT revoked_at IS NOT NULL FROM voice_leases WHERE id=$1`, []any{f.lease}, []any{&state.leaseRevoked}},
		{`SELECT count(*) FROM voice_sfu_revocations WHERE lease_id=$1`, []any{f.lease}, []any{&state.queue}},
		{`SELECT count(*) FROM audit_events WHERE event_type='PASSWORD_RESET_APPLIED' AND target_user_id=$1`, []any{f.user}, []any{&state.audit}},
	} {
		if err := f.pool.QueryRow(ctx, check.sql, check.args...).Scan(check.dest...); err != nil {
			t.Fatal(err)
		}
	}
	return state
}
func (f resetPreflightFixture) assertApplied(t *testing.T, newPassword string) {
	t.Helper()
	state := f.state(t)
	if !state.used || !state.sessionRevoked || state.otherRevoked || !state.leaseRevoked || state.queue != 1 || state.audit != 1 {
		t.Fatal("reset, session/lease revocation, outbox and audit did not apply exactly once")
	}
	valid, err := password.Verify(context.Background(), newPassword, state.hash)
	if err != nil || !valid {
		t.Fatal("replacement hash is not compatible with native verifier")
	}
	old, err := password.Verify(context.Background(), preflightOldPassword, state.hash)
	if err != nil || old {
		t.Fatal("original password still works after reset")
	}
}
