package soundpostgres_test

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
	p "voice-platform/backend/internal/voice/sound_preferences"
	db "voice-platform/backend/internal/voice/sound_preferences/postgres"
)

func TestStoredPreferencesUseAccountScopedCAS(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	const a = "11111111-1111-4111-8111-111111111111"
	const b = "22222222-2222-4222-8222-222222222222"
	for _, item := range []struct{ id, login string }{{a, "sound-a"}, {b, "sound-b"}} {
		if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,$2,'test','MEMBER')`, item.id, item.login); err != nil {
			t.Fatal(err)
		}
	}
	s := p.New(db.New(pool))
	x, err := s.Read(ctx, a)
	if err != nil || x.Revision != 0 || !x.Settings.Joined {
		t.Fatal("incorrect defaults", err)
	}
	value := x.Settings
	value.Joined = false
	saved, err := s.Save(ctx, a, 0, value)
	if err != nil || saved.Revision != 1 {
		t.Fatal("insert failed", err)
	}
	if _, err = s.Save(ctx, a, 0, x.Settings); !errors.Is(err, p.ErrConflict) {
		t.Fatal("concurrent insert did not conflict", err)
	}
	value.Left = false
	if _, err = s.Save(ctx, a, 1, value); err != nil {
		t.Fatal("update failed", err)
	}
	if _, err = s.Save(ctx, a, 1, x.Settings); !errors.Is(err, p.ErrConflict) {
		t.Fatal("stale update accepted", err)
	}
	one, err := s.Read(ctx, a)
	if err != nil || one.Revision != 2 || one.Settings.Joined || one.Settings.Left {
		t.Fatal("bad persisted value", err)
	}
	two, err := s.Read(ctx, b)
	if err != nil || two.Revision != 0 || !two.Settings.Joined || !two.Settings.Left {
		t.Fatal("account isolation failed", err)
	}
	var wg sync.WaitGroup
	results := make(chan error, 12)
	start := make(chan struct{})
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); <-start; _, err := s.Save(ctx, a, 2, value); results <- err }()
	}
	close(start)
	wg.Wait()
	close(results)
	success, conflicts := 0, 0
	for err := range results {
		if err == nil {
			success++
		} else if errors.Is(err, p.ErrConflict) {
			conflicts++
		} else {
			t.Fatalf("unexpected concurrent result: %v", err)
		}
	}
	if success != 1 || conflicts != 11 {
		t.Fatalf("expected one winner and 11 conflicts; got %d and %d", success, conflicts)
	}

}
