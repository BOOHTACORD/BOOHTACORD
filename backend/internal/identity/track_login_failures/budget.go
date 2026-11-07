// Package trackloginfailures independently bounds recent failed login work.
package trackloginfailures

import (
	"context"
	"crypto/sha256"
	"errors"
	"github.com/prometheus/client_golang/prometheus"
	"sync"
	"time"
)

var ErrLimited = errors.New("login failure budget exhausted")
var ErrSaturated = errors.New("login failure budget store full")

type Config struct {
	Limit, Capacity int
	Window          time.Duration
	Now             func() time.Time
}
type entry struct {
	failures, pending int
	reset             time.Time
}
type Budget struct {
	mu                  sync.Mutex
	config              Config
	entries             map[[sha256.Size]byte]*entry
	expires             expirations
	decisions, outcomes *prometheus.CounterVec
}

func New(c Config) (*Budget, error) {
	if c.Limit < 1 || c.Capacity < 1 || c.Window <= 0 {
		return nil, errors.New("invalid failure budget")
	}
	if c.Now == nil {
		c.Now = time.Now
	}
	return &Budget{config: c, entries: make(map[[sha256.Size]byte]*entry),
		decisions: prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_login_failure_admission_total", Help: "Process-local failure budget decisions."}, []string{"decision"}),
		outcomes:  prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_login_failure_completion_total", Help: "Failure budget reservation outcomes."}, []string{"outcome"})}, nil
}

// Reserve holds capacity before verification. The key is a normalized login;
// only its hash is kept in memory, never exposed as a metric or log label.
func (b *Budget) Reserve(ctx context.Context, normalized string) (*Permit, time.Duration, error) {
	if err := ctx.Err(); err != nil {
		b.decisions.WithLabelValues("cancelled").Inc()
		return nil, 0, err
	}
	key := sha256.Sum256([]byte(normalized))
	b.mu.Lock()
	defer b.mu.Unlock()
	if err := ctx.Err(); err != nil {
		b.decisions.WithLabelValues("cancelled").Inc()
		return nil, 0, err
	}
	now := b.config.Now()
	b.prune(now, 64)
	e := b.entries[key]
	if e != nil && !e.reset.IsZero() && !now.Before(e.reset) {
		if e.pending > 0 {
			b.decisions.WithLabelValues("limited").Inc()
			return nil, time.Second, ErrLimited
		}
		delete(b.entries, key)
		e = nil
	}
	if e == nil {
		if len(b.entries) >= b.config.Capacity {
			b.decisions.WithLabelValues("saturated").Inc()
			return nil, time.Second, ErrSaturated
		}
		e = &entry{}
		b.entries[key] = e
	}
	if e.failures+e.pending >= b.config.Limit {
		b.decisions.WithLabelValues("limited").Inc()
		delay := time.Second
		if !e.reset.IsZero() && e.reset.Sub(now) > delay {
			delay = e.reset.Sub(now)
		}
		return nil, delay, ErrLimited
	}
	e.pending++
	b.decisions.WithLabelValues("admitted").Inc()
	return &Permit{budget: b, key: key, entry: e}, 0, nil
}
