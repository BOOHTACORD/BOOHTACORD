// Package admitlogin reserves bounded, process-local login work before account
// lookup or password verification. It never changes persistent account state.
package admitlogin

import (
	"container/heap"
	"context"
	"crypto/sha256"
	"errors"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

var (
	ErrLimited   = errors.New("login attempt budget exhausted")
	ErrSaturated = errors.New("login attempt budget store full")
)

type Config struct {
	Limit       int
	Window      time.Duration
	MaxAccounts int
	Now         func() time.Time
}
type entry struct {
	used, inFlight int
	reset          time.Time
}
type Budget struct {
	mutex     sync.Mutex
	config    Config
	entries   map[[sha256.Size]byte]*entry
	expires   expirations
	inFlight  int
	decisions *prometheus.CounterVec
	outcomes  *prometheus.CounterVec
	duration  prometheus.Histogram
}

func New(config Config) (*Budget, error) {
	if config.Limit < 1 || config.Window <= 0 || config.MaxAccounts < 1 {
		return nil, errors.New("invalid login admission policy")
	}
	if config.Now == nil {
		config.Now = time.Now
	}
	return &Budget{config: config, entries: make(map[[sha256.Size]byte]*entry),
		decisions: prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_login_admission_total", Help: "Process-local login admission decisions before account lookup."}, []string{"decision"}),
		outcomes:  prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_login_completion_total", Help: "Completed login reservations by finite outcome; no identifiers."}, []string{"outcome"}),
		duration:  prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_login_admission_seconds", Help: "Atomic login admission duration; excludes account lookup and KDF.", Buckets: []float64{.000001, .00001, .0001, .001, .01}}),
	}, nil
}

// Reserve atomically charges all admitted attempts, including successful ones.
// Denials cannot extend the window. A running reservation survives expiry;
// callers never reuse its budget until the actual Login call has returned.
// normalized must be produced by the same login normalization as the verifier.
func (budget *Budget) Reserve(ctx context.Context, normalized string) (*Reservation, time.Duration, error) {
	started := time.Now()
	defer func() { budget.duration.Observe(time.Since(started).Seconds()) }()
	if err := ctx.Err(); err != nil {
		budget.decisions.WithLabelValues("cancelled").Inc()
		return nil, 0, err
	}
	key := sha256.Sum256([]byte(normalized))
	budget.mutex.Lock()
	defer budget.mutex.Unlock()
	if err := ctx.Err(); err != nil {
		budget.decisions.WithLabelValues("cancelled").Inc()
		return nil, 0, err
	}
	now := budget.config.Now()
	budget.prune(now, 64)
	current := budget.entries[key]
	if current != nil && !now.Before(current.reset) && current.inFlight == 0 {
		delete(budget.entries, key)
		current = nil
	}
	if current != nil && (current.used >= budget.config.Limit || !now.Before(current.reset)) {
		budget.decisions.WithLabelValues("limited").Inc()
		return nil, retry(current.reset.Sub(now)), ErrLimited
	}
	if current == nil {
		if len(budget.entries) >= budget.config.MaxAccounts {
			budget.decisions.WithLabelValues("saturated").Inc()
			// Retry is advisory: other active or running budgets may still hold capacity.
			delay := time.Second
			if len(budget.expires) > 0 {
				delay = retry(budget.expires[0].reset.Sub(now))
			}
			return nil, delay, ErrSaturated
		}
		current = &entry{reset: now.Add(budget.config.Window)}
		budget.entries[key] = current
		heap.Push(&budget.expires, expiry{key: key, entry: current, reset: current.reset})
	}
	current.used++
	current.inFlight++
	budget.inFlight++
	budget.decisions.WithLabelValues("admitted").Inc()
	return &Reservation{budget: budget, key: key, entry: current}, 0, nil
}

func retry(delay time.Duration) time.Duration {
	if delay < time.Second {
		return time.Second
	}
	return delay
}
