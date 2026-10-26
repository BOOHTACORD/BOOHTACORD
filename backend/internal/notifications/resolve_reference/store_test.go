package resolvereference

import (
	"context"
	"testing"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
	plan "voice-platform/backend/internal/notifications/plan_delivery"
	p "voice-platform/backend/internal/notifications/preferences"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
)

func TestResolveRequiresCurrentOwnerScopeAndDoesNotRead(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t)
	scope := fixture.Scope(t, pool)
	fixture.Enable(t, pool, fixture.Recipient, p.ModeMentions)
	node := fixture.AddDevice(t, pool, fixture.Recipient)
	if err := control.New(pool).Configure(ctx, true); err != nil {
		t.Fatal(err)
	}
	msg := fixture.AddDirect(t, pool, nil)
	now := time.Now().UTC().Add(6 * time.Second)
	planner := plan.New(pool)
	intent, found, err := planner.Claim(ctx, now)
	if err != nil || !found {
		t.Fatal(found, err)
	}
	if _, err = planner.Page(ctx, intent, scope, now); err != nil {
		t.Fatal(err)
	}
	var ref string
	if err = pool.QueryRow(ctx, `SELECT id::text FROM notification_deliveries`).Scan(&ref); err != nil {
		t.Fatal(err)
	}
	store := New(pool, scope)
	request := Request{ref, node.Generation}
	for _, account := range []string{fixture.Author, fixture.Outsider} {
		if _, err = store.Resolve(ctx, account, request, now); err != ErrNotFound {
			t.Fatal("foreign DM", err)
		}
	}
	got, err := store.Resolve(ctx, fixture.Recipient, request, now)
	if err != nil || got.MessageID != msg || got.Kind != "DM" {
		t.Fatal(got, err)
	}
	var reads, opens int
	if err = pool.QueryRow(ctx, `SELECT (SELECT count(*)FROM direct_message_read_cursors),(SELECT value FROM notification_counters WHERE metric='opened')`).Scan(&reads, &opens); err != nil || reads != 0 || opens != 1 {
		t.Fatal(reads, opens, err)
	}
	if _, err = store.Resolve(ctx, fixture.Recipient, request, now); err != nil {
		t.Fatal(err)
	}
	if err = pool.QueryRow(ctx, `SELECT value FROM notification_counters WHERE metric='opened'`).Scan(&opens); err != nil || opens != 1 {
		t.Fatal("double open count", opens, err)
	}
	wrong := scope
	wrong.Origin = "https://clone.example.invalid"
	if _, err = New(pool, wrong).Resolve(ctx, fixture.Recipient, request, now); err != ErrNotFound {
		t.Fatal("clone origin", err)
	}
	if err = store.Presented(ctx, fixture.Recipient, [32]byte{1}, request, now); err != ErrNotFound {
		t.Fatal("foreign session ACK", err)
	}
	if err = store.Presented(ctx, fixture.Recipient, [32]byte{2}, request, now); err != nil {
		t.Fatal(err)
	}
	if _, err = pool.Exec(ctx, `UPDATE sessions SET revoked_at=now()WHERE user_id=$1`, fixture.Recipient); err != nil {
		t.Fatal(err)
	}
	if _, err = store.Resolve(ctx, fixture.Recipient, request, now); err != ErrNotFound {
		t.Fatal("revoked route", err)
	}
}
