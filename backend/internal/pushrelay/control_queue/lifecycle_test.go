package controlqueue_test

import (
	"context"
	"github.com/google/uuid"
	"testing"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	accept "voice-platform/backend/internal/pushrelay/accept_notification"
	control "voice-platform/backend/internal/pushrelay/control_queue"
	fixture "voice-platform/backend/internal/pushrelay/test_scenario"
)

func TestKillRetainsNoReplayAndRecordsQuarantine(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t)
	now := time.Now().UTC()
	grant, key := fixture.Pair(t, pool, now)
	in := accept.Input{GrantID: grant.GrantID, Payload: delivery.Payload{Version: 1, Generation: 1, BindingRef: grant.BindingID, NotificationRef: uuid.NewString(), GroupRef: uuid.NewString(), Template: "activity", ExpiresAt: now.Add(time.Minute)}}
	service := accept.Service{Database: pool, Box: fixture.Box(t), Namespace: "staging"}
	if _, err := service.Accept(ctx, fixture.Signed(t, key, "tenant", grant.TenantID, "POST", "/v1/notifications", in, now), in, now); err != nil {
		t.Fatal(err)
	}
	controller := control.Store{Database: pool}
	for _, kill := range []bool{true, true, false} {
		if err := controller.Kill(ctx, kill); err != nil {
			t.Fatal(err)
		}
	}
	var pending, revoked int
	if err := pool.QueryRow(ctx, `SELECT pending,(SELECT COALESCE(sum(value),0) FROM relay_counters WHERE outcome='revoked') FROM relay_policy`).Scan(&pending, &revoked); err != nil || pending != 0 || revoked != 1 {
		t.Fatal("quarantine must be visible once", pending, revoked, err)
	}
	old, err := service.Accept(ctx, fixture.Signed(t, key, "tenant", grant.TenantID, "POST", "/v1/notifications", in, now), in, now)
	if err != nil || old.State != "revoked" {
		t.Fatal("resume replayed old delivery", old, err)
	}
}
