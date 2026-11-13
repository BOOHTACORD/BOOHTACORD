package pool

import (
	"context"
	"errors"
	"net/url"
	"os"
	"testing"
	"time"

	"voice-platform/backend/internal/testsupport/databasecheck"
)

func TestPartitionReservesSessionConnectionUnderMainSaturation(t *testing.T) {
	address := os.Getenv("VOICE_PLATFORM_TEST_DATABASE_URL")
	if address == "" {
		t.Skip("disposable PostgreSQL is unavailable")
	}
	if _, err := databasecheck.Config(address, os.Getenv("TEST_DATABASE_URL")); err != nil {
		t.Fatal(err)
	}
	parsed, err := url.Parse(address)
	if err != nil {
		t.Fatal("invalid test database URL")
	}
	params := parsed.Query()
	params.Set("pool_max_conns", "2")
	parsed.RawQuery = params.Encode()
	ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
	defer cancel()
	metrics := NewMetrics()
	main, session, err := OpenPartitionedObserved(ctx, parsed.String(), metrics)
	if err != nil {
		t.Fatal("open disposable pools:", err)
	}
	defer main.Close()
	defer session.Close()
	defer metrics.StopExport()
	busy, err := main.Acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer busy.Release()
	blockedCtx, stop := context.WithTimeout(ctx, 100*time.Millisecond)
	defer stop()
	if conn, err := main.Acquire(blockedCtx); !errors.Is(err, context.DeadlineExceeded) {
		if conn != nil {
			conn.Release()
		}
		t.Fatal("main pool should be saturated")
	}
	reserved, err := session.Acquire(ctx)
	if err != nil {
		t.Fatal("reserved session connection unavailable:", err)
	}
	defer reserved.Release()
	stats := metrics.snapshot()
	if stats["max"] != 2 || stats["acquired"] != 2 || stats["total"] != 2 {
		t.Fatalf("combined pool statistics incorrect: %#v", stats)
	}
}

func TestSingleConnectionConfigurationRemainsShared(t *testing.T) {
	address := os.Getenv("VOICE_PLATFORM_TEST_DATABASE_URL")
	if address == "" {
		t.Skip("disposable PostgreSQL is unavailable")
	}
	if _, err := databasecheck.Config(address, os.Getenv("TEST_DATABASE_URL")); err != nil {
		t.Fatal(err)
	}
	parsed, err := url.Parse(address)
	if err != nil {
		t.Fatal("invalid test database URL")
	}
	params := parsed.Query()
	params.Set("pool_max_conns", "1")
	parsed.RawQuery = params.Encode()
	ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
	defer cancel()
	metrics := NewMetrics()
	main, session, err := OpenPartitionedObserved(ctx, parsed.String(), metrics)
	if err != nil {
		t.Fatal("open disposable pool:", err)
	}
	defer main.Close()
	defer metrics.StopExport()
	if main != session || metrics.snapshot()["max"] != 1 {
		t.Fatal("single-connection deployment must use one shared pool")
	}
}
