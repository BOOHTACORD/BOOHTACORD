package notifyleaserevocation

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	replaypostgres "voice-platform/backend/internal/realtime/replay_event/postgres"
)

func TestPostgresOutboxRetriesWhenCriticalQueueIsFull(t *testing.T) {
	pool := newNotificationTestPool(t)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	owner, category, channel, lease := uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString()
	for _, row := range []struct {
		sql  string
		args []any
	}{
		{"INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'pressure_owner','Owner','test','MEMBER')", []any{owner}},
		{"INSERT INTO categories(id,name,position) VALUES($1,'Voice',0)", []any{category}},
		{"INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$2,'Voice','VOICE',0)", []any{channel, category}},
		{"INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)", []any{make([]byte, 32), owner}},
		{"INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest,revoked_at,revocation_reason) VALUES($1,$2,$3,$4,now(),'KICK')", []any{lease, owner, channel, make([]byte, 32)}},
		{"INSERT INTO voice_sfu_revocations(lease_id,channel_id) VALUES($1,$2)", []any{lease, channel}},
	} {
		if _, err := pool.Exec(ctx, row.sql, row.args...); err != nil {
			t.Fatal(err)
		}
	}
	hub := eventhub.New(1)
	hub.SetJournal(replaypostgres.New(pool))
	ownerSocket := hub.Subscribe(owner)
	defer ownerSocket.Close()
	for _, id := range []string{"one", "two"} {
		hub.PublishToAccounts([]string{owner}, eventhub.Event{EventID: id, Kind: "presence.changed"})
	}
	other := eventhub.Event{EventID: uuid.NewString(), Kind: "voice.lease_revoked", OccurredAt: time.Now().UTC(), Payload: map[string]any{"lease_id": uuid.NewString(), "reason": "KICK"}}
	if err := hub.PublishToAccountsDurable(ctx, []string{owner}, other); err != nil {
		t.Fatal(err)
	}
	service := New(NewRepository(NewPoolDatabase(pool)), hub)
	if count, err := service.Dispatch(ctx, 10); count != 0 || err == nil {
		t.Fatalf("saturated dispatch count=%d error=%v", count, err)
	}
	var emitted bool
	if err := pool.QueryRow(ctx, "SELECT notification_emitted_at IS NOT NULL FROM voice_sfu_revocations WHERE lease_id=$1", lease).Scan(&emitted); err != nil || emitted {
		t.Fatalf("outbox prematurely marked: emitted=%t error=%v", emitted, err)
	}
	ownerSocket.AcknowledgeOverflow()
	<-ownerSocket.Events()
	if _, err := pool.Exec(ctx, "UPDATE voice_sfu_revocations SET notification_claimed_at=now()-interval '31 seconds' WHERE lease_id=$1", lease); err != nil {
		t.Fatal(err)
	}
	if count, err := service.Dispatch(ctx, 10); count != 1 || err != nil {
		t.Fatalf("retry count=%d error=%v", count, err)
	}
	select {
	case event := <-ownerSocket.Events():
		if event.Kind != "voice.lease_revoked" || event.Payload["lease_id"] != lease {
			t.Fatal("retry did not deliver the intended revocation")
		}
	case <-ctx.Done():
		t.Fatal("retry event was not delivered")
	}
}
