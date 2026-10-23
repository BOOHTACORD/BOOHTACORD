package password_test

import (
	"context"
	"errors"
	"testing"
	"time"

	reset "voice-platform/backend/internal/identity/complete_password_reset"
	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/session"
)

func TestResetPreflightPostgresRejectsWithoutKDFOrMutation(t *testing.T) {
	for _, kind := range []string{"malformed", "unknown", "expired", "used"} {
		t.Run(kind, func(t *testing.T) {
			f := newResetPreflightFixture(t)
			token := f.token.Token
			switch kind {
			case "malformed":
				token = "malformed"
			case "unknown":
				issued, err := session.Issue()
				if err != nil {
					t.Fatal("cannot prepare synthetic token")
				}
				token = issued.Token
			case "expired":
				if _, err := f.pool.Exec(context.Background(), `UPDATE password_resets SET expires_at=now()-interval '1 second' WHERE token_digest=$1`, f.token.Digest[:]); err != nil {
					t.Fatal(err)
				}
			case "used":
				if _, err := f.pool.Exec(context.Background(), `UPDATE password_resets SET used_at=now() WHERE token_digest=$1`, f.token.Digest[:]); err != nil {
					t.Fatal(err)
				}
			}
			before := f.state(t)
			count := password.CountDerivationsForTest(t)
			err := reset.New(f.repository).Complete(context.Background(), reset.Input{Token: token, Password: preflightNewPassword})
			if !errors.Is(err, reset.ErrInvalidOrExpired) || count() != 0 || f.state(t) != before {
				t.Fatal("invalid capability performed native KDF or mutated PostgreSQL state")
			}
		})
	}
}

func TestResetPreflightPostgresReadOnlySuccessAndReuse(t *testing.T) {
	f := newResetPreflightFixture(t)
	before := f.state(t)
	if err := f.repository.Preflight(context.Background(), f.token.Digest); err != nil || f.state(t) != before {
		t.Fatal("preflight must not consume token or change access")
	}
	count := password.CountDerivationsForTest(t)
	service := reset.New(f.repository)
	if err := service.Complete(context.Background(), reset.Input{Token: f.token.Token, Password: preflightNewPassword}); err != nil || count() != 1 {
		t.Fatal("valid reset must execute exactly one native KDF")
	}
	f.assertApplied(t, preflightNewPassword)
	applied, work := f.state(t), count()
	if err := service.Complete(context.Background(), reset.Input{Token: f.token.Token, Password: "synthetic second replacement password"}); !errors.Is(err, reset.ErrInvalidOrExpired) || count() != work || f.state(t) != applied {
		t.Fatal("reused capability reached KDF or changed applied reset")
	}
}

func TestResetPreflightPostgresDeadlineFailsClosed(t *testing.T) {
	f := newResetPreflightFixture(t)
	before := f.state(t)
	tx, err := f.pool.Begin(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback(context.Background())
	if _, err := tx.Exec(context.Background(), `LOCK TABLE password_resets IN ACCESS EXCLUSIVE MODE`); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()
	unknown, issueErr := session.Issue()
	if issueErr != nil {
		t.Fatal("cannot prepare synthetic unknown token")
	}
	count := password.CountDerivationsForTest(t)
	err = reset.New(f.repository).Complete(ctx, reset.Input{Token: unknown.Token, Password: preflightNewPassword})
	if !errors.Is(err, context.DeadlineExceeded) || count() != 0 {
		t.Fatal("blocked preflight did not stop on parent deadline before KDF")
	}
	if err := tx.Rollback(context.Background()); err != nil {
		t.Fatal(err)
	}
	if f.state(t) != before {
		t.Fatal("failed preflight changed reset/access state")
	}
}

func TestResetPreflightPostgresFinalFailureRollsBackAllChanges(t *testing.T) {
	f := newResetPreflightFixture(t)
	ctx := context.Background()
	before := f.state(t)
	if _, err := f.pool.Exec(ctx, `CREATE FUNCTION qa_reject_reset_audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic reset audit failure'; END $$;
 CREATE TRIGGER qa_fail_reset BEFORE INSERT ON audit_events FOR EACH ROW WHEN (NEW.event_type='PASSWORD_RESET_APPLIED') EXECUTE FUNCTION qa_reject_reset_audit()`); err != nil {
		t.Fatal(err)
	}
	count := password.CountDerivationsForTest(t)
	service := reset.New(f.repository)
	err := service.Complete(ctx, reset.Input{Token: f.token.Token, Password: preflightNewPassword})
	if err == nil || errors.Is(err, reset.ErrInvalidOrExpired) || count() != 1 || f.state(t) != before {
		t.Fatal("final SQL failure did not atomically roll back token/password/revocations/outbox/audit")
	}
	if _, err := f.pool.Exec(ctx, `DROP TRIGGER qa_fail_reset ON audit_events`); err != nil {
		t.Fatal(err)
	}
	if err := service.Complete(ctx, reset.Input{Token: f.token.Token, Password: preflightNewPassword}); err != nil || count() != 2 {
		t.Fatal("rolled-back token did not remain usable")
	}
	f.assertApplied(t, preflightNewPassword)
}
