package cleanupdelivery_test

import (
	"context"
	"testing"
	"time"
	cleanup "voice-platform/backend/internal/notifications/cleanup_delivery"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
)

func TestExpiredEnrollmentIsFencedAndSecretCleared(t *testing.T) {
	pool := fixture.New(t)
	ctx := context.Background()
	device := fixture.AddDevice(t, pool, fixture.Recipient)
	now := time.Now().UTC()
	if _, err := pool.Exec(ctx, `UPDATE notification_devices SET state='registering',enrollment_until=$2 WHERE id=$1::uuid`, device.ID, now.Add(-time.Minute)); err != nil {
		t.Fatal(err)
	}
	if err := cleanup.New(pool).Run(ctx, now); err != nil {
		t.Fatal(err)
	}
	var state string
	var generation int64
	var cleared bool
	if err := pool.QueryRow(ctx, `SELECT state,generation,secret_cipher IS NULL FROM notification_devices WHERE id=$1::uuid`, device.ID).Scan(&state, &generation, &cleared); err != nil || state != "stale" || generation != device.Generation+1 || !cleared {
		t.Fatal(state, generation, cleared, err)
	}
	if err := cleanup.New(pool).Run(ctx, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT generation FROM notification_devices WHERE id=$1::uuid`, device.ID).Scan(&generation); err != nil || generation != device.Generation+1 {
		t.Fatal("cleanup repeated the fence", generation, err)
	}
}
