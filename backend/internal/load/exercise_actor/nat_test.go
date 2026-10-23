package exercise_actor

import (
	"context"
	"sync/atomic"
	"testing"
	"voice-platform/backend/internal/load/record_results"
)

func TestSharedNATExpectsQuotaAndKeepsObserved429(t *testing.T) {
	f := newFixture(t)
	defer f.close()
	f.enforceNAT = true
	r := record_results.New()
	a := New(f.manifest, 0, r, &atomic.Int64{})
	if err := a.SharedNAT(context.Background()); err != nil {
		t.Fatal(err)
	}
	if r.Snapshot()["login"].Count != 10 || r.Snapshot()["login"].Statuses[204] != 8 || r.Snapshot()["login"].Statuses[401] != 2 || r.Snapshot()["login"].Errors != 0 || r.Snapshot()["nat_limit"].Statuses[429] != 1 || r.Snapshot()["nat_limit"].Errors != 0 {
		t.Fatal(r.Snapshot())
	}
	if f.natAttempts != 11 || f.natAccounts[f.manifest.Accounts[0].Login] != 8 {
		t.Fatal("profile must retain ten source admissions without over-spending one account")
	}
}
