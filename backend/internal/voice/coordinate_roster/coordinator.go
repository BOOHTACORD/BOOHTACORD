// Package coordinateroster coalesces authorized roster refreshes by account.
package coordinateroster

import (
	"context"
	"sync"
	"sync/atomic"
	"time"
)

type Coordinator struct {
	config      Config
	lister      Lister
	changes     <-chan struct{}
	mu          sync.Mutex
	accounts    map[string]*account
	subscribers int
	jobs        chan job
	closed      bool
	running     atomic.Bool
	observer    Observer
}

func New(config Config, lister Lister, changes <-chan struct{}, observers ...Observer) (*Coordinator, error) {
	if lister == nil || config.Workers < 1 || config.Workers > 16 || config.MaxAccounts < 1 || config.MaxAccounts > 5000 || config.MaxSubscribers < 1 || config.MaxSubscribers > 5000 || config.MaxSnapshotBytes < 1 || config.MaxSnapshotBytes > 1<<20 || config.PollInterval <= 0 || config.ReadTimeout <= 0 {
		return nil, ErrInvalidConfig
	}
	var observer Observer
	if len(observers) > 0 {
		observer = observers[0]
	}
	return &Coordinator{config: config, lister: lister, changes: changes, observer: observer,
		accounts: make(map[string]*account), jobs: make(chan job, config.MaxAccounts)}, nil
}

// Run owns one ticker and a fixed number of workers until the parent stops.
func (c *Coordinator) Run(ctx context.Context) {
	if !c.running.CompareAndSwap(false, true) {
		return
	}
	var workers sync.WaitGroup
	for i := 0; i < c.config.Workers; i++ {
		workers.Add(1)
		go func() { defer workers.Done(); c.worker(ctx) }()
	}
	ticker := time.NewTicker(c.config.PollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			c.shutdown()
			workers.Wait()
			return
		case <-ticker.C:
			c.Invalidate()
		case _, ok := <-c.changes:
			if !ok {
				c.changes = nil
			} else {
				c.Invalidate()
			}
		}
	}
}

// Invalidate is a hint; the lister remains the only source of roster truth.
func (c *Coordinator) Invalidate() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed {
		return
	}
	for _, a := range c.accounts {
		a.epoch++
		a.dirty = true
		if a.cancel != nil {
			a.cancel()
		}
		c.schedule(a)
	}
}

func (c *Coordinator) schedule(a *account) {
	if a.pending || !a.dirty {
		return
	}
	select {
	case c.jobs <- job{account: a, epoch: a.epoch}:
		a.pending, a.dirty = true, false
	default:
		// A canceled account can leave stale queued work; never block under mu.
	}
}

func (c *Coordinator) scheduleWaiting() {
	if c.closed {
		return
	}
	for _, a := range c.accounts {
		c.schedule(a)
	}
}
