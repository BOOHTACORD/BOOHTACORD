package password

import (
	"context"
	"crypto/rand"
	"errors"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

func TestAdmissionCancellationAndIdempotentRelease(t *testing.T) {
	gate := newAdmission(1)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if permit, err := gate.acquire(ctx); !errors.Is(err, context.Canceled) || permit != nil {
		t.Fatal("cancelled admission reserved a slot")
	}
	permit, err := gate.acquire(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := gate.acquire(context.Background()); !errors.Is(err, ErrBusy) {
		t.Fatal("full gate must reject immediately")
	}
	permit.release()
	permit.release()
	if len(gate.slots) != 0 {
		t.Fatal("permit leaked")
	}
}

func TestExpiredContextAndErrorsDoNotLeakCapacity(t *testing.T) {
	count := CountDerivationsForTest(t)
	ctx, cancel := context.WithDeadline(context.Background(), time.Unix(1, 0))
	defer cancel()
	if _, err := Hash(ctx, "synthetic password"); !errors.Is(err, context.DeadlineExceeded) || count() != 0 {
		t.Fatal("expired request started work")
	}
	if _, err := Verify(context.Background(), "synthetic password", "malformed"); !errors.Is(err, ErrInvalidHash) || count() != 0 {
		t.Fatal("malformed hash started work")
	}
	original := rand.Reader
	t.Cleanup(func() { rand.Reader = original })
	rand.Reader = strings.NewReader("")
	if _, err := Hash(context.Background(), "synthetic password"); err == nil || count() != 0 {
		t.Fatal("entropy failure started work")
	}
	rand.Reader = original
	if _, err := Hash(context.Background(), "synthetic password"); err != nil || count() != 1 || len(kdfAdmission.slots) != 0 {
		t.Fatal("error/cancellation leaked capacity")
	}
}

func TestCancelAfterReservationDoesNotStartWorkOrLeak(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	count := CountDerivationsForTest(t)
	// The cancellation occurs after admission's pre-check snapshot, before
	// its returned permit is used. No scheduler timing assumption is needed.
	_, err := derive(&cancelOnCheck{Context: ctx, cancel: cancel}, "synthetic password", make([]byte, saltLength))
	if !errors.Is(err, context.Canceled) || count() != 0 || len(kdfAdmission.slots) != 0 {
		t.Fatal("reservation/cancellation race leaked work or capacity")
	}
}

type cancelOnCheck struct {
	context.Context
	cancel  context.CancelFunc
	checked bool
}

func (ctx *cancelOnCheck) Err() error {
	if !ctx.checked {
		ctx.checked = true
		ctx.cancel()
		return nil
	}
	return ctx.Context.Err()
}

func TestRealKDFConcurrencyCancellationAndSaturation(t *testing.T) {
	original := deriveKey
	var active, peak atomic.Int64
	entered := make(chan struct{}, activeLimit)
	release := make(chan struct{})
	deriveKey = func(p, s []byte, rounds, memory uint32, threads uint8, length uint32) []byte {
		n := active.Add(1)
		for old := peak.Load(); n > old && !peak.CompareAndSwap(old, n); old = peak.Load() {
		}
		entered <- struct{}{}
		<-release
		defer active.Add(-1)
		return original(p, s, rounds, memory, threads, length)
	}
	t.Cleanup(func() { deriveKey = original })
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan error, activeLimit)
	var workers sync.WaitGroup
	var unblock sync.Once
	defer func() { unblock.Do(func() { close(release) }); workers.Wait() }()
	for range activeLimit {
		workers.Add(1)
		go func() { defer workers.Done(); _, err := Hash(ctx, "synthetic password"); done <- err }()
	}
	for range activeLimit {
		select {
		case <-entered:
		case <-time.After(10 * time.Second):
			t.Fatal("workers did not enter KDF")
		}
	}
	cancel()
	// Cancellation must not detach live Argon2 or release its active slots.
	if len(kdfAdmission.slots) != activeLimit || active.Load() != activeLimit {
		t.Fatal("cancelled in-flight work released capacity early")
	}
	_, busy := Hash(context.Background(), "synthetic password")
	unblock.Do(func() { close(release) })
	for range activeLimit {
		if err := <-done; !errors.Is(err, context.Canceled) {
			t.Fatal("in-flight cancellation not propagated")
		}
	}
	if !errors.Is(busy, ErrBusy) || peak.Load() != activeLimit || len(kdfAdmission.slots) != 0 {
		t.Fatal("parallelism exceeded, saturation bypassed or permits leaked")
	}
}

func TestAdmissionMetricsAreBoundedAndPrivate(t *testing.T) {
	gate := newAdmission(1)
	permit, _ := gate.acquire(context.Background())
	_, _ = gate.acquire(context.Background())
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	_, _ = gate.acquire(ctx)
	registry := prometheus.NewPedanticRegistry()
	registry.MustRegister(newCollector(gate))
	metrics, err := registry.Gather()
	if err != nil {
		t.Fatal(err)
	}
	for _, family := range metrics {
		for _, metric := range family.Metric {
			if len(metric.Label) != 0 {
				t.Fatal("KDF metrics must not contain identifiers")
			}
		}
		switch family.GetName() {
		case "voice_platform_auth_kdf_active":
			if family.Metric[0].Gauge.GetValue() != 1 {
				t.Fatal("active metric")
			}
		case "voice_platform_auth_kdf_waiting":
			if family.Metric[0].Gauge.GetValue() != 0 {
				t.Fatal("zero-queue metric")
			}
		case "voice_platform_auth_kdf_rejected_total", "voice_platform_auth_kdf_cancelled_total":
			if family.Metric[0].Counter.GetValue() != 1 {
				t.Fatal("admission outcome metric")
			}
		}
	}
	permit.release()
}

func BenchmarkSupportedKDF(b *testing.B) {
	for b.Loop() {
		if _, err := Hash(context.Background(), "synthetic benchmark password"); err != nil {
			b.Fatal(err)
		}
	}
}
