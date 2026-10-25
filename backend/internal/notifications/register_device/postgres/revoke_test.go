package registerdevicepostgres

import (
	"context"
	"errors"
	"testing"
	list "voice-platform/backend/internal/notifications/list_devices"
	d "voice-platform/backend/internal/notifications/register_device"
	revoke "voice-platform/backend/internal/notifications/revoke_device"
)

func TestRevokeCannotBeUndoneByOldCallback(t *testing.T) {
	ctx := context.Background()
	pool := newPool(t)
	store := New(pool)
	r := record()
	first, err := store.Register(ctx, r, 0)
	if err != nil {
		t.Fatal(err)
	}
	revoker := revoke.New(pool, r.Origin, r.InstallationID)
	if err = revoker.Revoke(ctx, other, first.ID, 1); !errors.Is(err, revoke.ErrNotFound) {
		t.Fatal("cross-account revoke accepted", err)
	}
	if err = revoker.Revoke(ctx, account, first.ID, 1); err != nil {
		t.Fatal(err)
	}
	if err = revoker.Revoke(ctx, account, first.ID, 1); err != nil {
		t.Fatal("repeat revoke not idempotent", err)
	}
	if _, err = store.Register(ctx, r, 0); !errors.Is(err, d.ErrConflict) {
		t.Fatal("old initial registration revived device", err)
	}
	refreshed := r
	refreshed.Generation = 2
	if _, err = store.Register(ctx, refreshed, 1); !errors.Is(err, d.ErrConflict) {
		t.Fatal("old refresh revived device", err)
	}
	rows, err := list.New(pool, r.Origin, r.InstallationID).List(ctx, account)
	if err != nil || len(rows) != 1 || rows[0].State != "revoked" || rows[0].Generation != 2 {
		t.Fatal(rows, err)
	}
	foreign, err := list.New(pool, r.Origin, r.InstallationID).List(ctx, other)
	if err != nil || len(foreign) != 0 {
		t.Fatal("foreign devices exposed", err)
	}
}
func TestCreationBudgetSurvivesRevocation(t *testing.T) {
	ctx := context.Background()
	pool := newPool(t)
	store := New(pool)
	for i := 0; i < 5; i++ {
		r := record()
		saved, err := store.Register(ctx, r, 0)
		if err != nil {
			t.Fatal(err)
		}
		if err = revoke.New(pool, r.Origin, r.InstallationID).Revoke(ctx, account, saved.ID, 1); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := store.Register(ctx, record(), 0); !errors.Is(err, d.ErrLimit) {
		t.Fatal("revoke bypassed creation budget", err)
	}
}
