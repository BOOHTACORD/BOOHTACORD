package dispatchdelivery

import (
	"context"
	"testing"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
)

func TestDispatchRechecksReadAndIssuingSession(t *testing.T) {
	for _, which := range []string{"read", "logout", "mute", "delete", "kill"} {
		t.Run(which, func(t *testing.T) {
			pool, store, job, scope, now := planned(t)
			ctx := context.Background()
			var err error
			switch which {
			case "read":
				_, err = pool.Exec(ctx, `INSERT INTO direct_message_read_cursors(account_id,direct_message_id,message_id,message_created_at) SELECT $1,direct_message_id,id,created_at FROM direct_message_messages WHERE id=$2`, job.AccountID, job.MessageID)
			case "logout":
				_, err = pool.Exec(ctx, `UPDATE sessions SET revoked_at=now()WHERE user_id=$1`, job.AccountID)
			case "mute":
				_, err = pool.Exec(ctx, `UPDATE notification_preferences SET settings=jsonb_set(settings,'{enabled}','false') WHERE account_id=$1`, job.AccountID)
			case "delete":
				_, err = pool.Exec(ctx, `UPDATE direct_message_messages SET deleted_at=now(),body='' WHERE id=$1`, job.MessageID)
			case "kill":
				err = control.New(pool).Kill(ctx, true)
			}
			if err != nil {
				t.Fatal(err)
			}
			_, ready, err := store.Begin(ctx, job, scope, fixture.Box(t), now)
			if which == "kill" {
				if err != ErrLostLease {
					t.Fatal(err)
				}
			} else if err != nil || ready {
				t.Fatal("ineligible send", ready, err)
			}
			state(t, pool, job.ID, "suppressed")
		})
	}
}
func TestCrashAfterRequestStartDoesNotResend(t *testing.T) {
	pool, store, job, scope, now := planned(t)
	ctx := context.Background()
	message, ready, err := store.Begin(ctx, job, scope, fixture.Box(t), now)
	if err != nil || !ready || len(message.Secret) == 0 || message.Payload.Validate(now) != nil {
		t.Fatal(ready, err)
	}
	recovered, found, err := store.Claim(ctx, now.Add(31*time.Second))
	if err != nil || !found {
		t.Fatal(found, err)
	}
	if _, ready, err = store.Begin(ctx, recovered, scope, fixture.Box(t), now.Add(31*time.Second)); err != nil || ready {
		t.Fatal(ready, err)
	}
	state(t, pool, job.ID, "delivery_unknown")
	if err = store.Complete(ctx, job, Result{Outcome: "accepted_by_provider"}, now); err != ErrLostLease {
		t.Fatal("late callback changed recovered delivery", err)
	}
}
func TestRetryKeepsOriginalReferenceAndExpiry(t *testing.T) {
	pool, store, job, scope, now := planned(t)
	ctx := context.Background()
	if _, ready, err := store.Begin(ctx, job, scope, fixture.Box(t), now); err != nil || !ready {
		t.Fatal(ready, err)
	}
	if err := store.Complete(ctx, job, Result{Outcome: "retry", Reason: "provider_error", RetryAfter: 3 * time.Second}, now); err != nil {
		t.Fatal(err)
	}
	again, found, err := store.Claim(ctx, now.Add(10*time.Second))
	if err != nil || !found || again.ID != job.ID || !again.ExpiresAt.Equal(job.ExpiresAt) {
		t.Fatal(again, found, err)
	}
	if _, ready, err := store.Begin(ctx, again, scope, fixture.Box(t), now.Add(10*time.Second)); err != nil || !ready {
		t.Fatal(ready, err)
	}
	if err = store.Complete(ctx, again, Result{Outcome: "accepted_by_provider"}, now.Add(11*time.Second)); err != nil {
		t.Fatal(err)
	}
	state(t, pool, job.ID, "accepted_by_provider")
}
