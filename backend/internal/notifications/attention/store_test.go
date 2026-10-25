package attention

import (
	"context"
	"github.com/google/uuid"
	"testing"
	"time"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
)

func TestAttentionOwnVisibleConversationBoundedAndNotRead(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t)
	store := New(pool)
	now := time.Now().UTC()
	input := Input{uuid.NewString(), "DIRECT_MESSAGE", fixture.Direct, true}
	if err := store.Update(ctx, fixture.Outsider, [32]byte{3}, input, now); err != ErrUnavailable {
		t.Fatal("admin DM bypass", err)
	}
	if err := store.Update(ctx, fixture.Recipient, [32]byte{1}, input, now); err != ErrUnavailable {
		t.Fatal("foreign session", err)
	}
	for i := 0; i < 10; i++ {
		input.ViewID = uuid.NewString()
		if err := store.Update(ctx, fixture.Recipient, [32]byte{2}, input, now); err != nil {
			t.Fatal(i, err)
		}
	}
	if err := store.Update(ctx, fixture.Recipient, [32]byte{2}, input, now); err != nil {
		t.Fatal("idempotent refresh", err)
	}
	input.ViewID = uuid.NewString()
	if err := store.Update(ctx, fixture.Recipient, [32]byte{2}, input, now); err != ErrUnavailable {
		t.Fatal("unbounded views", err)
	}
	var count, reads int
	var expires time.Time
	if err := pool.QueryRow(ctx, `SELECT count(*),max(expires_at),(SELECT count(*)FROM direct_message_read_cursors) FROM notification_attention`).Scan(&count, &expires, &reads); err != nil || count != 10 || reads != 0 || expires.Sub(now) > 31*time.Second {
		t.Fatal(count, reads, expires, err)
	}
	if err := store.Update(ctx, fixture.Recipient, [32]byte{2}, input, now.Add(31*time.Second)); err != nil {
		t.Fatal("expired slots not released", err)
	}
	input.Visible = false
	if err := store.Update(ctx, fixture.Recipient, [32]byte{2}, input, now.Add(32*time.Second)); err != nil {
		t.Fatal(err)
	}
}
