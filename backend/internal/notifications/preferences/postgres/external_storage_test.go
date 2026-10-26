package preferencespostgres_test

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5/pgxpool"
	"sync"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	p "voice-platform/backend/internal/notifications/preferences"
	db "voice-platform/backend/internal/notifications/preferences/postgres"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

const auditAccount = "11111111-1111-4111-8111-111111111111"

func auditPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'notify-audit','Audit','test','MEMBER')`, auditAccount); err != nil {
		t.Fatal(err)
	}
	return pool
}

func TestExternalStorageCreateUpdateAndStale(t *testing.T) {
	repo := db.New(auditPool(t))
	ctx := context.Background()
	settings := p.Default()
	first, err := repo.Save(ctx, p.Input{AccountID: auditAccount, Settings: settings})
	if err != nil {
		t.Fatal("create:", err)
	}
	if first.Revision != 1 {
		t.Fatalf("first revision=%d", first.Revision)
	}
	settings.Enabled = true
	second, err := repo.Save(ctx, p.Input{AccountID: auditAccount, ExpectedRevision: 1, Settings: settings})
	if err != nil {
		t.Fatal("update:", err)
	}
	if second.Revision != 2 || !second.Enabled {
		t.Fatalf("bad update: %+v", second)
	}
	_, err = repo.Save(ctx, p.Input{AccountID: auditAccount, ExpectedRevision: 1, Settings: p.Default()})
	if !errors.Is(err, p.ErrConflict) {
		t.Fatalf("stale overwrite error=%v", err)
	}
	read, err := repo.Read(ctx, auditAccount)
	if err != nil || read.Revision != 2 || !read.Enabled {
		t.Fatalf("persisted state %+v err=%v", read, err)
	}
}

func TestExternalStorageConcurrentFirstWriter(t *testing.T) {
	repo := db.New(auditPool(t))
	ctx := context.Background()
	start := make(chan struct{})
	var wait sync.WaitGroup
	results := make(chan error, 12)
	for i := 0; i < 12; i++ {
		wait.Add(1)
		go func() {
			defer wait.Done()
			<-start
			_, err := repo.Save(ctx, p.Input{AccountID: auditAccount, Settings: p.Default()})
			results <- err
		}()
	}
	close(start)
	wait.Wait()
	close(results)
	wins := 0
	for err := range results {
		if err == nil {
			wins++
		} else if !errors.Is(err, p.ErrConflict) {
			t.Errorf("unexpected error: %v", err)
		}
	}
	if wins != 1 {
		t.Fatalf("successful first writers=%d; want 1", wins)
	}
}

func TestExternalStorageImportNeverOptsInAndOnlyOnce(t *testing.T) {
	repo := db.New(auditPool(t))
	ctx := context.Background()
	settings := p.Default()
	settings.Enabled = true
	settings.DM.Mode = p.ModeNone
	settings.Text.Mode = p.ModeAll
	imported, err := repo.Save(ctx, p.Input{AccountID: auditAccount, Settings: settings, Import: true})
	if err != nil {
		t.Fatal("import:", err)
	}
	if imported.Enabled || !imported.Imported || imported.DM.Mode != p.ModeAll || imported.Text.Mode != p.ModeMentions {
		t.Fatalf("unsafe implicit migration: %+v", imported)
	}
	_, err = repo.Save(ctx, p.Input{AccountID: auditAccount, ExpectedRevision: imported.Revision, Settings: p.Default(), Import: true})
	if !errors.Is(err, p.ErrAlreadyImported) {
		t.Fatalf("reimport error=%v", err)
	}
}
