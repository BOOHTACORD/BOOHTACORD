package password

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

// ErrBusy means no process-local KDF capacity is available. It is never an
// invalid-password result. The queue has zero waiting slots: callers retry
// manually after a controlled HTTP response instead of retaining passwords.
var ErrBusy = errors.New("password verification capacity unavailable")

const activeLimit = 4

type admission struct {
	slots               chan struct{}
	rejected, cancelled prometheus.Counter
	duration, work      prometheus.Histogram
}

var kdfAdmission = newAdmission(activeLimit)

func newAdmission(limit int) *admission {
	return &admission{
		slots:     make(chan struct{}, limit),
		rejected:  prometheus.NewCounter(prometheus.CounterOpts{Name: "voice_platform_auth_kdf_rejected_total", Help: "KDF admissions rejected at process capacity."}),
		cancelled: prometheus.NewCounter(prometheus.CounterOpts{Name: "voice_platform_auth_kdf_cancelled_total", Help: "KDF operations abandoned after observed context cancellation."}),
		duration:  prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_auth_kdf_admission_seconds", Help: "Fail-fast KDF admission duration; no waiting queue.", Buckets: []float64{.000001, .00001, .0001, .001, .01}}),
		work:      prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_auth_kdf_work_seconds", Help: "Actual synchronous Argon2 work duration, including cancelled in-flight work.", Buckets: []float64{.01, .025, .05, .1, .25, .5, 1}}),
	}
}

type lease struct {
	owner *admission
	once  sync.Once
}

func (lease *lease) release() { lease.once.Do(func() { <-lease.owner.slots }) }

func (gate *admission) acquire(ctx context.Context) (*lease, error) {
	started := time.Now()
	defer func() { gate.duration.Observe(time.Since(started).Seconds()) }()
	if err := ctx.Err(); err != nil {
		gate.cancelled.Inc()
		return nil, err
	}
	select {
	case gate.slots <- struct{}{}:
		return &lease{owner: gate}, nil
	default:
		gate.rejected.Inc()
		return nil, ErrBusy
	}
}

func derive(ctx context.Context, plainText string, salt []byte) ([]byte, error) {
	permit, err := kdfAdmission.acquire(ctx)
	if err != nil {
		return nil, err
	}
	defer permit.release()
	if err := ctx.Err(); err != nil {
		kdfAdmission.cancelled.Inc()
		return nil, err
	}
	started := time.Now()
	// Argon2 is synchronous. Cancellation cannot release its permit until the
	// real computation ends, and never spawns detached work.
	key := deriveKey([]byte(plainText), salt, iterations, memoryKiB, parallelism, keyLength)
	kdfAdmission.work.Observe(time.Since(started).Seconds())
	if err := ctx.Err(); err != nil {
		kdfAdmission.cancelled.Inc()
		return nil, err
	}
	return key, nil
}
