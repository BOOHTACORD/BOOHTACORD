package notifyleaserevocation

import (
	"context"
	"testing"

	"github.com/google/uuid"
)

func TestRepositoryPostgresCommitRetryAndSFUIndependence(t *testing.T) {
	pool := newNotificationTestPool(t)
	context := context.Background()
	ownerID, categoryID, channelID := uuid.NewString(), uuid.NewString(), uuid.NewString()
	for _, row := range []struct {
		statement string
		args      []any
	}{
		{"INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'leaseowner', 'Lease Owner', 'test-only', 'MEMBER')", []any{ownerID}},
		{"INSERT INTO categories (id, name, position) VALUES ($1, 'Voice', 0)", []any{categoryID}},
		{"INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1, $2, 'Voice', 'VOICE', 0)", []any{channelID, categoryID}},
	} {
		if _, err := pool.Exec(context, row.statement, row.args...); err != nil {
			t.Fatal("seed revocation owner/channel:", err)
		}
	}
	sessionDigest := make([]byte, 32)
	if _, err := pool.Exec(context, "INSERT INTO sessions (token_digest, user_id) VALUES ($1, $2)", sessionDigest, ownerID); err != nil {
		t.Fatal("seed test session:", err)
	}
	leaseID := uuid.NewString()
	transaction, err := pool.Begin(context)
	if err != nil {
		t.Fatal(err)
	}
	_, err = transaction.Exec(context, "INSERT INTO voice_leases (id, user_id, channel_id, session_token_digest, revoked_at, revocation_reason) VALUES ($1, $2, $3, $4, now(), 'KICK')", leaseID, ownerID, channelID, sessionDigest)
	if err == nil {
		_, err = transaction.Exec(context, "INSERT INTO voice_sfu_revocations (lease_id, channel_id) VALUES ($1, $2)", leaseID, channelID)
	}
	if err != nil {
		_ = transaction.Rollback(context)
		t.Fatal("seed rolled-back revocation:", err)
	}
	if err := transaction.Rollback(context); err != nil {
		t.Fatal(err)
	}
	repository := NewRepository(NewPoolDatabase(pool))
	if items, err := repository.Claim(context, 10); err != nil || len(items) != 0 {
		t.Fatalf("uncommitted revocation was visible: %#v, %v", items, err)
	}
	if _, err := pool.Exec(context, "INSERT INTO voice_leases (id, user_id, channel_id, session_token_digest, revoked_at, revocation_reason) VALUES ($1, $2, $3, $4, now(), 'KICK')", leaseID, ownerID, channelID, sessionDigest); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(context, "INSERT INTO voice_sfu_revocations (lease_id, channel_id, completed_at) VALUES ($1, $2, now())", leaseID, channelID); err != nil {
		t.Fatal(err)
	}
	items, err := repository.Claim(context, 10)
	if err != nil || len(items) != 1 || items[0].LeaseID != leaseID || items[0].UserID != ownerID || items[0].Reason != "KICK" {
		t.Fatalf("committed claim = %#v, %v", items, err)
	}
	if competing, err := repository.Claim(context, 10); err != nil || len(competing) != 0 {
		t.Fatalf("competing claim = %#v, %v", competing, err)
	}
	if _, err := pool.Exec(context, "UPDATE voice_sfu_revocations SET notification_claimed_at = now() - interval '31 seconds' WHERE lease_id = $1", leaseID); err != nil {
		t.Fatal(err)
	}
	retried, err := repository.Claim(context, 10)
	if err != nil || len(retried) != 1 || retried[0].ClaimToken == items[0].ClaimToken {
		t.Fatalf("retry claim = %#v, %v", retried, err)
	}
	if err := repository.MarkEmitted(context, items[0]); err != ErrStaleClaim {
		t.Fatalf("stale mark = %v", err)
	}
	if err := repository.MarkEmitted(context, retried[0]); err != nil {
		t.Fatalf("mark emitted: %v", err)
	}
	if items, err := repository.Claim(context, 10); err != nil || len(items) != 0 {
		t.Fatalf("emitted revocation reclaimed: %#v, %v", items, err)
	}
}

func TestAFKMoveNotificationWaitsForSFUCleanup(t *testing.T) {
	pool := newNotificationTestPool(t)
	ctx := context.Background()
	ownerID, categoryID := uuid.NewString(), uuid.NewString()
	channelID, afkChannelID, leaseID := uuid.NewString(), uuid.NewString(), uuid.NewString()
	sessionDigest := make([]byte, 32)
	login := "afk_notice_" + ownerID[:8]
	for _, seed := range []struct {
		query string
		args  []any
	}{
		{`INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,$2,'test-only','MEMBER')`, []any{ownerID, login}},
		{`INSERT INTO categories(id,name,position) VALUES($1,'AFK notice test',0)`, []any{categoryID}},
		{`INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$3,'Voice','VOICE',0),($2,$3,'AFK','VOICE',1)`, []any{channelID, afkChannelID, categoryID}},
		{`INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, []any{sessionDigest, ownerID}},
		{`INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest,revoked_at,revocation_reason) VALUES($1,$2,$3,$4,now(),'AFK_MOVE')`, []any{leaseID, ownerID, channelID, sessionDigest}},
		{`INSERT INTO voice_sfu_revocations(lease_id,channel_id,target_channel_id) VALUES($1,$2,$3)`, []any{leaseID, channelID, afkChannelID}},
	} {
		if _, err := pool.Exec(ctx, seed.query, seed.args...); err != nil {
			t.Fatal("seed AFK notification fixture:", err)
		}
	}
	repository := NewRepository(NewPoolDatabase(pool))
	if items, err := repository.Claim(ctx, 10); err != nil || len(items) != 0 {
		t.Fatalf("pending SFU cleanup was announced: %#v, %v", items, err)
	}
	if _, err := pool.Exec(ctx, `UPDATE voice_sfu_revocations SET completed_at=now() WHERE lease_id=$1`, leaseID); err != nil {
		t.Fatal("complete SFU cleanup:", err)
	}
	items, err := repository.Claim(ctx, 10)
	if err != nil || len(items) != 1 || items[0].Reason != "AFK_MOVE" || items[0].TargetChannelID == nil || *items[0].TargetChannelID != afkChannelID {
		t.Fatalf("completed AFK revocation claim = %#v, %v", items, err)
	}
}
