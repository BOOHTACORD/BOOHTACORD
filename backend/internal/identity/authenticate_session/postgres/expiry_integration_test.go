package sessionpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"

	"github.com/google/uuid"
	"voice-platform/backend/internal/identity/authenticate_session"
)

func TestRepositoryRejectsIdleAndAbsoluteExpiredSessions(t *testing.T) {
	pool := newSessionFixture(t)
	ctx := context.Background()
	userID := uuid.NewString()
	if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,'QA session','test','MEMBER')`, userID, "qa-session-expiry-"+userID); err != nil {
		t.Fatal(err)
	}
	digests := map[string][sha256.Size]byte{
		"active":   sha256.Sum256([]byte("active session")),
		"idle":     sha256.Sum256([]byte("idle session")),
		"absolute": sha256.Sum256([]byte("absolute session")),
	}
	for kind, digest := range digests {
		_, err := pool.Exec(ctx, `INSERT INTO sessions(user_id,token_digest,last_active_at,expires_at)
			VALUES($1,$2,CASE WHEN $3='idle' THEN now()-interval '31 days' ELSE now() END,
			CASE WHEN $3='absolute' THEN now()-interval '1 second' ELSE now()+interval '1 day' END)`, userID, digest[:], kind)
		if err != nil {
			t.Fatal(err)
		}
	}
	auth := New(NewPoolDatabase(pool))
	if _, err := auth.FindActive(ctx, digests["active"]); err != nil {
		t.Fatalf("active session error = %v", err)
	}
	if principal, err := New(NewPoolDatabase(pool)).FindActive(ctx, digests["active"]); err != nil || principal.AccountID != userID {
		t.Fatalf("session after API repository recreation = %#v, error = %v", principal, err)
	}
	for _, kind := range []string{"idle", "absolute"} {
		if _, err := auth.FindActive(ctx, digests[kind]); !errors.Is(err, authenticatesession.ErrSessionNotFound) {
			t.Errorf("%s expired session error = %v", kind, err)
		}
	}
}
