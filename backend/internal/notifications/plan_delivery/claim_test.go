package plandelivery

import (
	"context"
	"sync"
	"testing"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
)

func TestCompetingClaimsAndExpiredLease(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t)
	if err := control.New(pool).Configure(ctx, true); err != nil {
		t.Fatal(err)
	}
	fixture.AddDirect(t, pool, nil)
	now := time.Now().UTC().Add(6 * time.Second)
	store := New(pool)
	results := make(chan Intent, 2)
	failures := make(chan error, 2)
	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			in, found, err := store.Claim(ctx, now)
			if err != nil {
				failures <- err
			}
			if found {
				results <- in
			}
		}()
	}
	wg.Wait()
	close(results)
	close(failures)
	for err := range failures {
		t.Error(err)
	}
	var first Intent
	count := 0
	for in := range results {
		first = in
		count++
	}
	if count != 1 {
		t.Fatal("multiple current owners", count)
	}
	recovered, found, err := store.Claim(ctx, now.Add(31*time.Second))
	if err != nil || !found || recovered.ID != first.ID || recovered.LeaseOwner == first.LeaseOwner {
		t.Fatal("lease recovery failed", found, err)
	}
}
func TestKillSwitchQuarantinesPendingAndSurvivesConfigure(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t)
	controller := control.New(pool)
	if err := controller.Configure(ctx, true); err != nil {
		t.Fatal(err)
	}
	fixture.AddText(t, pool, nil)
	if err := controller.Kill(ctx, true); err != nil {
		t.Fatal(err)
	}
	if err := controller.Configure(ctx, true); err != nil {
		t.Fatal(err)
	}
	if _, found, err := New(pool).Claim(ctx, time.Now().Add(time.Minute)); err != nil || found {
		t.Fatal("kill switch reset on restart", found, err)
	}
	if err := controller.Kill(ctx, false); err != nil {
		t.Fatal(err)
	}
	if _, found, err := New(pool).Claim(ctx, time.Now().Add(time.Minute)); err != nil || found {
		t.Fatal("old queue replayed after re-enable", found, err)
	}
	fixture.AddText(t, pool, nil)
	if _, found, err := New(pool).Claim(ctx, time.Now().Add(time.Minute)); err != nil || !found {
		t.Fatal("new work not accepted", found, err)
	}
	var pending, active int
	if err := pool.QueryRow(ctx, `SELECT intent_pending,(SELECT count(*)FROM notification_outbox WHERE state IN('pending','planning')) FROM notification_runtime_policy`).Scan(&pending, &active); err != nil || pending != active {
		t.Fatal("counter drift", pending, active, err)
	}
}
