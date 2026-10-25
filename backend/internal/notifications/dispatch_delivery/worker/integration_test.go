package notificationworker_test

import (
	"context"
	"sync"
	"testing"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	worker "voice-platform/backend/internal/notifications/dispatch_delivery/worker"
	plan "voice-platform/backend/internal/notifications/plan_delivery"
	prefs "voice-platform/backend/internal/notifications/preferences"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
)

type fakeProvider struct {
	mu       sync.Mutex
	seen     []delivery.Payload
	accepted chan struct{}
	check    func(delivery.Message)
}

func (f *fakeProvider) Send(ctx context.Context, m delivery.Message) delivery.Result {
	f.check(m)
	f.mu.Lock()
	defer f.mu.Unlock()
	f.seen = append(f.seen, m.Payload)
	if len(f.seen) == 1 {
		return delivery.Result{Outcome: "retry", Reason: "provider_error"}
	}
	close(f.accepted)
	return delivery.Result{Outcome: "accepted_by_provider"}
}
func TestRealWorkerCommitsBeforeProviderAndRetriesStableEnvelope(t *testing.T) {
	pool := fixture.New(t)
	ctx := context.Background()
	scope := fixture.Scope(t, pool)
	fixture.Enable(t, pool, fixture.Recipient, prefs.ModeMentions)
	fixture.AddDevice(t, pool, fixture.Recipient)
	if err := control.New(pool).Configure(ctx, true); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `UPDATE notification_runtime_policy SET grace_seconds=0`); err != nil {
		t.Fatal(err)
	}
	provider := &fakeProvider{accepted: make(chan struct{})}
	provider.check = func(m delivery.Message) {
		check, cancel := context.WithTimeout(ctx, time.Second)
		defer cancel()
		var marked bool
		if err := pool.QueryRow(check, `SELECT attempt_started_at IS NOT NULL FROM notification_deliveries WHERE id=$1::uuid`, m.Payload.NotificationRef).Scan(&marked); err != nil || !marked {
			t.Error("attempt not durably visible before external call", err)
		}
	}
	w := worker.Start(ctx, worker.Config{Planner: plan.New(pool), Dispatch: delivery.New(pool), Scope: scope, Box: fixture.Box(t), Transports: map[string]delivery.Transport{"web_push": provider}})
	defer func() {
		stop, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		if err := w.Stop(stop); err != nil {
			t.Error(err)
		}
	}()
	fixture.AddDirect(t, pool, nil)
	select {
	case <-provider.accepted:
	case <-time.After(15 * time.Second):
		t.Fatal("bounded worker did not deliver synthetic job")
	}
	provider.mu.Lock()
	defer provider.mu.Unlock()
	if len(provider.seen) != 2 || provider.seen[0] != provider.seen[1] {
		t.Fatal("retry changed logical envelope or original TTL", provider.seen)
	}
}
