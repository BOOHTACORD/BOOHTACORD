package dispatchdelivery

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
	plan "voice-platform/backend/internal/notifications/plan_delivery"
	p "voice-platform/backend/internal/notifications/preferences"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
)

func planned(t *testing.T) (*pgxpool.Pool, Store, Job, reader.Scope, time.Time) {
	t.Helper()
	ctx := context.Background()
	pool := fixture.New(t)
	scope := fixture.Scope(t, pool)
	fixture.Enable(t, pool, fixture.Recipient, p.ModeMentions)
	fixture.AddDevice(t, pool, fixture.Recipient)
	if err := control.New(pool).Configure(ctx, true); err != nil {
		t.Fatal(err)
	}
	fixture.AddDirect(t, pool, nil)
	now := time.Now().UTC().Add(7 * time.Second)
	planner := plan.New(pool)
	in, found, err := planner.Claim(ctx, now)
	if err != nil || !found {
		t.Fatal(found, err)
	}
	if _, err = planner.Page(ctx, in, scope, now); err != nil {
		t.Fatal(err)
	}
	store := New(pool)
	job, found, err := store.Claim(ctx, now.Add(time.Second))
	if err != nil || !found {
		t.Fatal(found, err)
	}
	return pool, store, job, scope, now.Add(time.Second)
}
func state(t *testing.T, pool *pgxpool.Pool, id string, want string) {
	t.Helper()
	var got string
	var pending, actual int
	if err := pool.QueryRow(context.Background(), `SELECT state FROM notification_deliveries WHERE id=$1`, id).Scan(&got); err != nil || got != want {
		t.Fatal(got, want, err)
	}
	if err := pool.QueryRow(context.Background(), `SELECT delivery_pending,(SELECT count(*)FROM notification_deliveries WHERE state IN('pending','claimed','retry')) FROM notification_runtime_policy`).Scan(&pending, &actual); err != nil || pending != actual {
		t.Fatal("counter drift", pending, actual, err)
	}
}
