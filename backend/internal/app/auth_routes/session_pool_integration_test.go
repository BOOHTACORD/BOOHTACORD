package authroutes

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestSessionPoolRemainsAuthoritativeWhenMainPoolIsBusy(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	fixture := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, fixture); err != nil {
		t.Fatal(err)
	}
	const actor = "11111111-1111-4111-8111-111111111111"
	issued, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := fixture.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role)
VALUES ($1,'session_pool_qa','QA','fixture','MEMBER')`, actor); err != nil {
		t.Fatal(err)
	}
	if _, err := fixture.Exec(ctx, `INSERT INTO sessions(user_id,token_digest) VALUES ($1,$2)`, actor, issued.Digest[:]); err != nil {
		t.Fatal(err)
	}
	config := fixture.Config().Copy()
	config.MinConns, config.MaxConns = 0, 1
	main, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal(err)
	}
	defer main.Close()
	reserved, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal(err)
	}
	defer reserved.Close()
	busy, err := main.Acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer busy.Release()
	service := sessionServiceFor(reserved, nil)
	principal, err := service.Authenticate(ctx, issued.Token)
	if err != nil || principal.AccountID != actor {
		t.Fatal("reserved session lookup failed", err)
	}
	if _, err := fixture.Exec(ctx, `UPDATE sessions SET revoked_at=now() WHERE token_digest=$1`, issued.Digest[:]); err != nil {
		t.Fatal(err)
	}
	if _, err := service.Authenticate(ctx, issued.Token); !errors.Is(err, auth.ErrUnauthenticated) {
		t.Fatal("reserved pool accepted a revoked session")
	}
}
