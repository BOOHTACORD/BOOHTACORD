package acceptnotification_test

import (
	"context"
	"github.com/google/uuid"
	"testing"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	accept "voice-platform/backend/internal/pushrelay/accept_notification"
	fixture "voice-platform/backend/internal/pushrelay/test_scenario"
)

func TestQueuedExpiryCannotOutlivePhysicalGrant(t *testing.T) {
	pool := fixture.New(t)
	ctx := context.Background()
	now := time.Now().UTC().Truncate(time.Second)
	grant, key := fixture.Pair(t, pool, now)
	expiry := now.Add(10 * time.Second)
	if _, err := pool.Exec(ctx, `UPDATE relay_grants SET expires_at=$2 WHERE id=$1::uuid`, grant.GrantID, expiry); err != nil {
		t.Fatal(err)
	}
	input := accept.Input{GrantID: grant.GrantID, Payload: delivery.Payload{Version: 1, Generation: 1, BindingRef: grant.BindingID, NotificationRef: uuid.NewString(), GroupRef: uuid.NewString(), Template: "direct_message", ExpiresAt: now.Add(time.Hour)}}
	service := accept.Service{Database: pool, Box: fixture.Box(t), Namespace: "staging"}
	out, err := service.Accept(ctx, fixture.Signed(t, key, "tenant", grant.TenantID, "POST", "/v1/notifications", input, now), input, now)
	if err != nil || !out.ExpiresAt.Equal(expiry) {
		t.Fatal("grant expiry must bound provider TTL", out, err)
	}
	var actual time.Time
	if err = pool.QueryRow(ctx, `SELECT expires_at FROM relay_jobs WHERE job_ref=$1::uuid`, input.Payload.NotificationRef).Scan(&actual); err != nil || !actual.Equal(expiry) {
		t.Fatal(actual, err)
	}
}
