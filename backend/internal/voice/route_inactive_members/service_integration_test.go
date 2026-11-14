package routeinactivemembers

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

func newRouteFixture(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	t.Cleanup(cancel)
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal("run migrations:", err)
	}
	return pool
}

func TestRouteInactiveRevokesLeaseAndStoresAFKDestination(t *testing.T) {
	pool := newRouteFixture(t)
	ctx := context.Background()
	userID, categoryID := uuid.NewString(), uuid.NewString()
	sourceID, afkID, leaseID := uuid.NewString(), uuid.NewString(), uuid.NewString()
	sessionDigest := make([]byte, 32)
	login := "afk_" + userID[:8]
	for _, seed := range []struct {
		query string
		args  []any
	}{
		{`INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,$2,'test-only','MEMBER')`, []any{userID, login}},
		{`INSERT INTO categories(id,name,position) VALUES($1,'AFK test',0)`, []any{categoryID}},
		{`INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$3,'Source','VOICE',0),($2,$3,'AFK','VOICE',1)`, []any{sourceID, afkID, categoryID}},
		{`UPDATE guild_settings SET afk_channel_id=$1,afk_timeout_seconds=60 WHERE singleton=TRUE`, []any{afkID}},
		{`INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, []any{sessionDigest, userID}},
		{`INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest) VALUES($1,$2,$3,$4)`, []any{leaseID, userID, sourceID, sessionDigest}},
	} {
		if _, err := pool.Exec(ctx, seed.query, seed.args...); err != nil {
			t.Fatal("seed AFK routing fixture:", err)
		}
	}

	presence := eventhub.New(8)
	subscription := presence.SubscribeAccountAt(userID, eventhub.Event{}, time.Now().Add(-2*time.Minute))
	defer subscription.Close()

	moved, err := New(pool, presence).RouteInactive(ctx)
	if err != nil || moved != 1 {
		t.Fatalf("routed members = %d, err = %v", moved, err)
	}
	var reason, channelID, targetChannelID string
	if err := pool.QueryRow(ctx, `SELECT lease.revocation_reason,revocation.channel_id::text,revocation.target_channel_id::text FROM voice_leases lease JOIN voice_sfu_revocations revocation ON revocation.lease_id=lease.id WHERE lease.id=$1`, leaseID).Scan(&reason, &channelID, &targetChannelID); err != nil {
		t.Fatal("read routed lease:", err)
	}
	if reason != "AFK_MOVE" || channelID != sourceID || targetChannelID != afkID {
		t.Fatalf("revocation = reason:%q source:%q target:%q", reason, channelID, targetChannelID)
	}
}
