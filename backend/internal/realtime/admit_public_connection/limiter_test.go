package admitpublicconnection

import (
	"fmt"
	"sync"
	"testing"
)

func TestRejectsInvalidConfiguration(t *testing.T) {
	for _, config := range []Config{{}, {GlobalLimit: 20, SourceLimit: 19}, {GlobalLimit: 19, SourceLimit: 20}} {
		if _, err := New(config); err == nil {
			t.Fatalf("accepted invalid config: %+v", config)
		}
	}
}

func TestSourceQuotaAllowsNATAndNormalizesAddresses(t *testing.T) {
	limiter, err := New(Config{GlobalLimit: 25, SourceLimit: 20})
	if err != nil {
		t.Fatal(err)
	}
	var releases []func()
	for i := 0; i < 20; i++ {
		source := "192.0.2.10"
		if i%2 == 0 {
			source = "::ffff:192.0.2.10"
		}
		release, ok := limiter.TryAcquire(source)
		if !ok {
			t.Fatalf("rejected NAT connection %d", i+1)
		}
		releases = append(releases, release)
	}
	if _, ok := limiter.TryAcquire("192.0.2.10"); ok {
		t.Fatal("source quota exceeded")
	}
	if _, ok := limiter.TryAcquire("not-an-ip"); ok {
		t.Fatal("accepted invalid IP")
	}
	releases[0]()
	releases[0]()
	if _, ok := limiter.TryAcquire("192.0.2.10"); !ok {
		t.Fatal("slot not released")
	}
	if _, ok := limiter.TryAcquire("192.0.2.10"); ok {
		t.Fatal("double release freed extra slot")
	}
	for _, release := range releases {
		release()
	}
}

func TestConcurrentGlobalLimitAndRelease(t *testing.T) {
	limiter, err := New(Config{GlobalLimit: 25, SourceLimit: 20})
	if err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	var mu sync.Mutex
	var releases []func()
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			if release, ok := limiter.TryAcquire(fmt.Sprintf("192.0.2.%d", i+1)); ok {
				mu.Lock()
				releases = append(releases, release)
				mu.Unlock()
			}
		}(i)
	}
	wg.Wait()
	if len(releases) != 25 {
		t.Fatalf("accepted %d connections, want 25", len(releases))
	}
	for _, release := range releases {
		wg.Add(1)
		go func(r func()) { defer wg.Done(); r(); r() }(release)
	}
	wg.Wait()
	if release, ok := limiter.TryAcquire("192.0.2.1"); !ok {
		t.Fatal("capacity not restored")
	} else {
		release()
	}
}
