package matrixchat

import (
	"context"
	"github.com/google/uuid"
	"time"
)

type Result struct {
	Samples      []time.Duration
	Ages         []time.Duration
	CreatedAfter time.Duration
	Duplicates   int
}

func (c *Collector) Finish(ctx context.Context, id string) ([]time.Duration, int, error) {
	result, err := c.FinishDetailed(ctx, id)
	return result.Samples, result.Duplicates, err
}

func (c *Collector) FinishDetailed(ctx context.Context, id string) (Result, error) {
	if ctx == nil || uuid.Validate(id) != nil {
		return Result{}, errObservation
	}
	defer func() { c.mu.Lock(); c.started = time.Time{}; c.seen = nil; c.mu.Unlock() }()
	var timer *time.Timer
	var settle <-chan time.Time
	settled := false
	defer func() {
		if timer != nil {
			timer.Stop()
		}
	}()
	for {
		c.mu.Lock()
		if c.started.IsZero() || c.failure != nil {
			c.mu.Unlock()
			return Result{}, errObservation
		}
		entry := c.seen[id]
		var samples []time.Duration
		var ages []time.Duration
		var createdAfter time.Duration
		duplicates := 0
		if entry != nil {
			samples = make([]time.Duration, 0, c.accounts)
			duplicates = entry.duplicates
			if !entry.occurred.IsZero() {
				createdAfter = entry.occurred.Sub(c.started)
			}
			for i, at := range entry.received {
				if !at.IsZero() {
					samples = append(samples, at.Sub(c.started))
					if !entry.occurred.IsZero() {
						ages = append(ages, entry.ages[i])
					}
				}
			}
		}
		complete := len(samples) == c.accounts
		c.mu.Unlock()
		if complete && settled {
			return Result{Samples: samples, Ages: ages, CreatedAfter: createdAfter, Duplicates: duplicates}, nil
		}
		if complete && timer == nil {
			timer = time.NewTimer(100 * time.Millisecond)
			settle = timer.C
		}
		select {
		case <-ctx.Done():
			return Result{}, ctx.Err()
		case <-c.wake:
		case <-settle:
			settled, settle = true, nil
		}
	}
}
