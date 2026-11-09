// Package matrixchat measures synthetic message delivery on an owned fixture.
package matrixchat

import (
	"errors"
	"github.com/google/uuid"
	"sync"
	"time"
)

var errObservation = errors.New("invalid or excessive message observations")

type observation struct {
	received         []time.Time
	occurred         time.Time
	timingSet, timed bool
	ages             []time.Duration
	duplicates       int
}
type Collector struct {
	mu        sync.Mutex
	accounts  int
	started   time.Time
	seen      map[string]*observation
	failure   error
	wake      chan struct{}
	presence  uint64
	auxiliary [2]uint64
}

func New(accounts int) (*Collector, error) {
	if accounts < 1 || accounts > 100 {
		return nil, errObservation
	}
	return &Collector{accounts: accounts, wake: make(chan struct{}, 1)}, nil
}

func (c *Collector) Begin(started time.Time) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if started.IsZero() || !c.started.IsZero() {
		return errObservation
	}
	c.started, c.seen, c.failure = started, make(map[string]*observation), nil
	return nil
}

func (c *Collector) Observe(index int, id string, at time.Time) {
	c.ObserveTimed(index, id, at, time.Time{})
}

func (c *Collector) ObserveTimed(index int, id string, at, occurred time.Time) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.started.IsZero() {
		return
	}
	if index < 0 || index >= c.accounts || uuid.Validate(id) != nil || at.Before(c.started) {
		c.failure = errObservation
	} else {
		entry := c.seen[id]
		if entry == nil && len(c.seen) < 4 {
			entry = &observation{received: make([]time.Time, c.accounts), ages: make([]time.Duration, c.accounts)}
			c.seen[id] = entry
		}
		if entry == nil {
			c.failure = errObservation
		} else if !entry.received[index].IsZero() {
			entry.duplicates++
		} else {
			entry.received[index] = at
			if entry.timingSet && entry.timed != !occurred.IsZero() {
				c.failure = errObservation
			}
			entry.timingSet, entry.timed = true, !occurred.IsZero()
			if !occurred.IsZero() {
				if (!entry.occurred.IsZero() && !entry.occurred.Equal(occurred)) || at.Before(occurred) || occurred.Before(c.started.Add(-time.Second)) {
					c.failure = errObservation
				} else {
					entry.occurred = occurred
					entry.ages[index] = at.Sub(occurred)
				}
			}
		}
	}
	select {
	case c.wake <- struct{}{}:
	default:
	}
}
