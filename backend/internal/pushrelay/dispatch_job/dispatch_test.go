package dispatchjob_test

import (
	"context"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	accept "voice-platform/backend/internal/pushrelay/accept_notification"
	dispatch "voice-platform/backend/internal/pushrelay/dispatch_job"
	fixture "voice-platform/backend/internal/pushrelay/test_scenario"
)

func ready(t *testing.T) (*pgxpool.Pool, dispatch.Store, dispatch.Work, time.Time) {
	t.Helper()
	ctx := context.Background()
	pool := fixture.New(t)
	now := time.Now().UTC()
	grant, key := fixture.Pair(t, pool, now)
	input := accept.Input{GrantID: grant.GrantID, Payload: delivery.Payload{Version: 1, Generation: 1, BindingRef: grant.BindingID, NotificationRef: uuid.NewString(), GroupRef: uuid.NewString(), Template: "direct_message", ExpiresAt: now.Add(time.Minute)}}
	service := accept.Service{Database: pool, Box: fixture.Box(t), Namespace: "staging"}
	if _, err := service.Accept(ctx, fixture.Signed(t, key, "tenant", grant.TenantID, "POST", "/v1/notifications", input, now), input, now); err != nil {
		t.Fatal(err)
	}
	store := dispatch.Store{Database: pool, Box: fixture.Box(t), Namespace: "staging"}
	for i := 0; i < 3; i++ {
		work, ok, err := store.Next(ctx, now)
		if err != nil {
			t.Fatal(err)
		}
		if ok {
			return pool, store, work, now
		}
	}
	t.Fatal("no runnable relay job")
	return nil, store, dispatch.Work{}, now
}
func assertCount(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	var pending, actual int
	if err := pool.QueryRow(context.Background(), `SELECT pending,(SELECT count(*)FROM relay_jobs WHERE state IN('pending','claimed','retry'))FROM relay_policy`).Scan(&pending, &actual); err != nil || pending != actual {
		t.Fatal("relay counter drift", pending, actual, err)
	}
}
func TestRelayAttemptCommitsBeforeIOAndCrashDoesNotResend(t *testing.T) {
	pool, store, work, now := ready(t)
	ctx := context.Background()
	tx, err := pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		t.Fatal(err)
	}
	if _, err = tx.Exec(ctx, `SELECT 1 FROM relay_policy FOR UPDATE NOWAIT`); err != nil {
		t.Fatal("provider request would hold queue lock", err)
	}
	_ = tx.Rollback(ctx)
	if work.Message.Target == "" || len(work.Message.Payload) == 0 {
		t.Fatal("missing transport input")
	}
	if _, ok, err := store.Next(ctx, now.Add(31*time.Second)); err != nil || ok {
		t.Fatal("ambiguous write was sent twice", ok, err)
	}
	var state string
	if err = pool.QueryRow(ctx, `SELECT state FROM relay_jobs WHERE id=$1`, work.Job.ID).Scan(&state); err != nil || state != "delivery_unknown" {
		t.Fatal(state, err)
	}
	if err = store.Complete(ctx, work.Job, delivery.Result{Outcome: "accepted_by_provider"}, now); err != dispatch.ErrLostLease {
		t.Fatal("late provider callback changed recovered status", err)
	}
	assertCount(t, pool)
}
func TestRelayRetryRetainsExpiryAndFreshRevokeWins(t *testing.T) {
	pool, store, work, now := ready(t)
	ctx := context.Background()
	if err := store.Complete(ctx, work.Job, delivery.Result{Outcome: "retry", RetryAfter: 3 * time.Second}, now); err != nil {
		t.Fatal(err)
	}
	next, ok, err := store.Next(ctx, now.Add(10*time.Second))
	if err != nil || !ok || next.Job.ID != work.Job.ID || !next.Job.ExpiresAt.Equal(work.Job.ExpiresAt) {
		var diagnostic string
		_ = pool.QueryRow(ctx, `SELECT state||' attempt='||attempts||' started='||(started_at IS NOT NULL)||' due='||(due_at<=$2)||' alive='||(expires_at>$2) FROM relay_jobs WHERE id=$1`, work.Job.ID, now.Add(10*time.Second)).Scan(&diagnostic)
		t.Log(diagnostic)
		t.Fatal(next.Job, ok, err)
	}
	if err = store.Complete(ctx, next.Job, delivery.Result{Outcome: "retry"}, now.Add(10*time.Second)); err != nil {
		t.Fatal(err)
	}
	if _, err = pool.Exec(ctx, `UPDATE relay_grants SET state='revoked' WHERE id=$1`, next.Job.GrantID); err != nil {
		t.Fatal(err)
	}
	if _, ok, err = store.Next(ctx, now.Add(20*time.Second)); err != nil || ok {
		t.Fatal("revoked grant sent", ok, err)
	}
	assertCount(t, pool)
}
