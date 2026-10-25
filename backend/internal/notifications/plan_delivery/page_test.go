package plandelivery

import (
	"context"
	"testing"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
	p "voice-platform/backend/internal/notifications/preferences"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
)

func TestDirectMentionPlansOneJobAndReadSuppressesAllDevices(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t)
	scope := fixture.Scope(t, pool)
	fixture.Enable(t, pool, fixture.Recipient, p.ModeMentions)
	fixture.AddDevice(t, pool, fixture.Recipient)
	if err := control.New(pool).Configure(ctx, true); err != nil {
		t.Fatal(err)
	}
	fixture.AddDirect(t, pool, []string{fixture.Recipient})
	now := time.Now().Add(6 * time.Second)
	store := New(pool)
	intent, found, err := store.Claim(ctx, now)
	if err != nil || !found {
		t.Fatal(found, err)
	}
	result, err := store.Page(ctx, intent, scope, now)
	if err != nil || result.Created != 1 || !result.Complete {
		t.Fatal(result, err)
	}
	var jobs int
	if err = pool.QueryRow(ctx, `SELECT count(*)FROM notification_deliveries`).Scan(&jobs); err != nil || jobs != 1 {
		t.Fatal(jobs, err)
	}
	if _, err = store.Page(ctx, intent, scope, now); err != ErrLostLease {
		t.Fatal("old worker repeated completed page", err)
	}
	fixture.AddDevice(t, pool, fixture.Recipient)
	message := fixture.AddDirect(t, pool, nil)
	if _, err = pool.Exec(ctx, `INSERT INTO direct_message_read_cursors(account_id,direct_message_id,message_id,message_created_at) SELECT $1,direct_message_id,id,created_at FROM direct_message_messages WHERE id=$2`, fixture.Recipient, message); err != nil {
		t.Fatal(err)
	}
	intent, found, err = store.Claim(ctx, now.Add(time.Second))
	if err != nil || !found {
		t.Fatal(found, err)
	}
	result, err = store.Page(ctx, intent, scope, now.Add(time.Second))
	if err != nil || result.Created != 0 {
		t.Fatal("read message planned", result, err)
	}
}
func TestEditedMentionIsNotANewNotification(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t)
	scope := fixture.Scope(t, pool)
	fixture.Enable(t, pool, fixture.Recipient, p.ModeMentions)
	fixture.AddDevice(t, pool, fixture.Recipient)
	if err := control.New(pool).Configure(ctx, true); err != nil {
		t.Fatal(err)
	}
	id := fixture.AddText(t, pool, nil)
	if _, err := pool.Exec(ctx, `UPDATE messages SET mention_user_ids=$1::uuid[],edited_at=now(),revision=revision+1 WHERE id=$2`, []string{fixture.Recipient}, id); err != nil {
		t.Fatal(err)
	}
	now := time.Now().Add(6 * time.Second)
	store := New(pool)
	intent, found, err := store.Claim(ctx, now)
	if err != nil || !found {
		t.Fatal(found, err)
	}
	result, err := store.Page(ctx, intent, scope, now)
	if err != nil || result.Created != 0 {
		t.Fatal("edit added push", result, err)
	}
}
