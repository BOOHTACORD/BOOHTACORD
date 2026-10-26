package dispatchdelivery

import (
	"context"
	"testing"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
)

func TestDeletedIssuingSessionReclaimsRoutesAndPendingBudget(t *testing.T) {
	pool, _, _, _, _ := planned(t)
	ctx := context.Background()
	if _, err := pool.Exec(ctx, `DELETE FROM sessions WHERE user_id=$1::uuid`, fixture.Recipient); err != nil {
		t.Fatal("notification metadata blocked native session deletion", err)
	}
	var pending, actual, devices int
	if err := pool.QueryRow(ctx, `SELECT delivery_pending,(SELECT count(*)FROM notification_deliveries),(SELECT count(*)FROM notification_devices)FROM notification_runtime_policy`).Scan(&pending, &actual, &devices); err != nil || pending != 0 || actual != 0 || devices != 0 {
		t.Fatal("cascade leaked queue budget", pending, actual, devices, err)
	}
}
