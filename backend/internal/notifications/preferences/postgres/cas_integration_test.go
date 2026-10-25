package preferencespostgres_test

import (
	"context"
	"errors"
	"testing"
	p "voice-platform/backend/internal/notifications/preferences"
	db "voice-platform/backend/internal/notifications/preferences/postgres"
)

func TestMissingRowDoesNotAcceptPositiveRevision(t *testing.T) {
	repo := db.New(auditPool(t))
	ctx := context.Background()
	_, err := repo.Save(ctx, p.Input{AccountID: auditAccount, ExpectedRevision: 9, Settings: p.Default()})
	if !errors.Is(err, p.ErrConflict) {
		t.Fatalf("error=%v", err)
	}
	got, err := repo.Read(ctx, auditAccount)
	if err != nil || got.Revision != 0 {
		t.Fatalf("state=%+v error=%v", got, err)
	}
}

func TestImportedStateSurvivesNormalUpdate(t *testing.T) {
	repo := db.New(auditPool(t))
	ctx := context.Background()
	first, err := repo.Save(ctx, p.Input{AccountID: auditAccount, Settings: p.Default(), Import: true})
	if err != nil {
		t.Fatal(err)
	}
	settings := p.Default()
	settings.Enabled = true
	settings.DM.Mode = p.ModeNone
	second, err := repo.Save(ctx, p.Input{AccountID: auditAccount, ExpectedRevision: first.Revision, Settings: settings})
	if err != nil {
		t.Fatal(err)
	}
	got, err := repo.Read(ctx, auditAccount)
	if err != nil || !got.Imported || !got.Enabled || got.Revision != second.Revision || got.DM.Mode != p.ModeNone {
		t.Fatalf("state=%+v error=%v", got, err)
	}
}

func TestImportCannotClobberExistingServerChoice(t *testing.T) {
	repo := db.New(auditPool(t))
	ctx := context.Background()
	settings := p.Default()
	settings.Text.Mode = p.ModeNone
	first, err := repo.Save(ctx, p.Input{AccountID: auditAccount, Settings: settings})
	if err != nil {
		t.Fatal(err)
	}
	_, err = repo.Save(ctx, p.Input{AccountID: auditAccount, ExpectedRevision: first.Revision, Settings: p.Default(), Import: true})
	if !errors.Is(err, p.ErrConflict) {
		t.Fatalf("error=%v", err)
	}
	got, err := repo.Read(ctx, auditAccount)
	if err != nil || got.Text.Mode != p.ModeNone || got.Imported || got.Revision != first.Revision {
		t.Fatalf("state=%+v error=%v", got, err)
	}
}
