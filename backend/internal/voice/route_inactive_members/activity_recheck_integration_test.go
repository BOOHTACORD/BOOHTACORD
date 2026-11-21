package routeinactivemembers

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestActivityWhileLeaseLockIsContendedCancelsAFKMove(t *testing.T) {
	pool := newRouteFixture(t)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	user, category, source, target, lease := uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString()
	login := "afk_" + user[:8]
	digest := []byte("01234567890123456789012345678901")
	for _, seed := range []struct {
		query string
		args  []any
	}{
		{`INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,$2,'test-only','MEMBER')`, []any{user, login}},
		{`INSERT INTO categories(id,name,position) VALUES($1,'AFK test',0)`, []any{category}},
		{`INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$3,'Source','VOICE',0),($2,$3,'AFK','VOICE',1)`, []any{source, target, category}},
		{`UPDATE guild_settings SET afk_channel_id=$1,afk_timeout_seconds=60 WHERE singleton=TRUE`, []any{target}},
		{`INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, []any{digest, user}},
		{`INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest) VALUES($1,$2,$3,$4)`, []any{lease, user, source, digest}},
	} {
		if _, err := pool.Exec(ctx, seed.query, seed.args...); err != nil {
			t.Fatal("seed fixture:", err)
		}
	}
	hub := eventhub.New(8)
	socket := hub.SubscribeAccountAt(user, eventhub.Event{}, time.Now().Add(-2*time.Minute))
	defer socket.Close()
	lock, err := pool.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer lock.Rollback(context.Background())
	if _, err = lock.Exec(ctx, `SELECT id FROM voice_leases WHERE id=$1 FOR UPDATE`, lease); err != nil {
		t.Fatal(err)
	}
	type outcome struct {
		moved bool
		err   error
	}
	result := make(chan outcome, 1)
	go func() { moved, err := New(pool, hub).move(ctx, user, target); result <- outcome{moved, err} }()
	var application string
	if err = pool.QueryRow(ctx, `SELECT current_setting('application_name')`).Scan(&application); err != nil {
		t.Fatal(err)
	}
	for {
		var waiting bool
		if err = pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name=$1 AND wait_event_type='Lock')`, application).Scan(&waiting); err != nil {
			t.Fatal(err)
		}
		if waiting {
			break
		}
		select {
		case <-ctx.Done():
			t.Fatal("move did not reach the contested lease lock")
		case <-time.After(10 * time.Millisecond):
		}
	}
	hub.ReportActivity(socket, time.Now())
	if err = lock.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	got := <-result
	if got.err != nil || got.moved {
		t.Fatalf("move after renewed activity = %v, err = %v", got.moved, got.err)
	}
	var revoked bool
	if err = pool.QueryRow(ctx, `SELECT revoked_at IS NOT NULL FROM voice_leases WHERE id=$1`, lease).Scan(&revoked); err != nil || revoked {
		t.Fatalf("lease revoked = %v, err = %v", revoked, err)
	}
}
