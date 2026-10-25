package dispatchdelivery

import (
	"context"
	"testing"
	p "voice-platform/backend/internal/notifications/preferences"
	prefstore "voice-platform/backend/internal/notifications/preferences/postgres"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
)

func TestUnrelatedTextPreferenceDoesNotDiscardPendingDM(t *testing.T) {
	pool, store, job, scope, now := planned(t)
	ctx := context.Background()
	repo := prefstore.New(pool)
	prefs, err := repo.Read(ctx, fixture.Recipient)
	if err != nil {
		t.Fatal(err)
	}
	prefs.Text.Mode = p.ModeNone
	if _, err = repo.Save(ctx, p.Input{AccountID: fixture.Recipient, ExpectedRevision: prefs.Revision, Settings: prefs}); err != nil {
		t.Fatal(err)
	}
	_, ready, err := store.Begin(ctx, job, scope, fixture.Box(t), now)
	if err != nil || !ready {
		t.Fatal("unrelated TEXT setting discarded an eligible DM", ready, err)
	}
}
