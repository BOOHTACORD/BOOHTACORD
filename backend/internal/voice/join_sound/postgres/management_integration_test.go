package soundstore_test

import (
	"context"
	"errors"
	"testing"
	s "voice-platform/backend/internal/voice/join_sound"
	db "voice-platform/backend/internal/voice/join_sound/postgres"
)

func verifyManagement(t *testing.T, ctx context.Context, repo db.Repository, owner, other s.Actor, id string) {
	t.Helper()
	if _, err := repo.Enable(ctx, other, false); !errors.Is(err, s.ErrNotFound) {
		t.Fatal("foreign management allowed", err)
	}
	sound, err := repo.Enable(ctx, owner, false)
	if err != nil || sound.Enabled {
		t.Fatal("disable", err)
	}
	if _, err = repo.Fetch(ctx, owner, id); err != nil {
		t.Fatal("disabled owner preview", err)
	}
	current, err := repo.Current(ctx, owner)
	if err != nil || current.ID != id || current.Enabled {
		t.Fatal("metadata", err)
	}
	if err = repo.Delete(ctx, owner); err != nil {
		t.Fatal("delete", err)
	}
	if _, err = repo.Fetch(ctx, owner, id); !errors.Is(err, s.ErrNotFound) {
		t.Fatal("deleted payload exposed", err)
	}
	if _, err = repo.Current(ctx, owner); !errors.Is(err, s.ErrNotFound) {
		t.Fatal("deleted metadata exposed", err)
	}
	if _, err = repo.Replace(ctx, owner, current.Revision, s.Audio{Bytes: []byte{1}, DurationMS: 1000}); !errors.Is(err, s.ErrNotFound) {
		t.Fatal("late upload restored deleted audio", err)
	}
}
