package observestate

import (
	"context"
	"testing"
	"time"

	"voice-platform/backend/internal/database/migrate"
	admission "voice-platform/backend/internal/maintenance/admission"
	admissionpostgres "voice-platform/backend/internal/maintenance/admission/postgres"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestObserverReconcilesOperatorDatabaseChange(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	service := admission.New(admissionpostgres.New(admissionpostgres.NewPoolDatabase(pool)))
	observer := New(service, 20*time.Millisecond, time.Second)
	runCtx, stop := context.WithCancel(context.Background())
	defer stop()
	go observer.Run(runCtx)
	sub := observer.Subscribe()
	defer sub.Close()
	if initial := receive(t, sub.Events()); !initial.Known || initial.Active {
		t.Fatalf("initial = %+v", initial)
	}
	if err := service.Set(ctx, true); err != nil {
		t.Fatal(err)
	}
	if changed := receive(t, sub.Events()); !changed.Known || !changed.Active || changed.Revision != 2 {
		t.Fatalf("changed = %+v", changed)
	}
}
