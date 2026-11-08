package soundpreferences

import (
	"context"
	"errors"
	"sync"
	"testing"
)

type memoryStore struct {
	mu     sync.Mutex
	values map[string]Snapshot
}

func (m *memoryStore) Read(_ context.Context, id string) (Snapshot, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	s, ok := m.values[id]
	if !ok {
		return Snapshot{Revision: 0, Settings: Default()}, nil
	}
	return s, nil
}
func (m *memoryStore) CompareAndSwap(_ context.Context, id string, revision int64, settings Settings) (Snapshot, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	current := m.values[id]
	if current.Revision != revision {
		return Snapshot{}, ErrConflict
	}
	next := Snapshot{Revision: revision + 1, Settings: settings}
	m.values[id] = next
	return next, nil
}
func TestServiceAccountIsolationAndOptimisticConcurrency(t *testing.T) {
	const a = "11111111-1111-4111-8111-111111111111"
	const b = "22222222-2222-4222-8222-222222222222"
	s := New(&memoryStore{values: map[string]Snapshot{}})
	ctx := context.Background()
	x, err := s.Read(ctx, a)
	if err != nil || !x.Settings.Joined {
		t.Fatal("missing default")
	}
	change := x.Settings
	change.Joined = false
	next, err := s.Save(ctx, a, x.Revision, change)
	if err != nil || next.Revision != 1 || next.Settings.Joined {
		t.Fatal("save failed")
	}
	if _, err = s.Save(ctx, a, 0, x.Settings); !errors.Is(err, ErrConflict) {
		t.Fatal("stale revision accepted")
	}
	other, err := s.Read(ctx, b)
	if err != nil || !other.Settings.Joined || other.Revision != 0 {
		t.Fatal("settings leaked to another account")
	}
	invalid := next.Settings
	invalid.Volume = 101
	if _, err = s.Save(ctx, a, next.Revision, invalid); err == nil {
		t.Fatal("invalid volume accepted")
	}
	after, _ := s.Read(ctx, a)
	if after.Revision != next.Revision || after.Settings.Joined {
		t.Fatal("failed save changed committed settings")
	}
	if _, err = s.Read(ctx, "not-an-account"); err == nil {
		t.Fatal("invalid account accepted")
	}
}
