package trackloginfailures

import (
	"container/heap"
	"crypto/sha256"
	"sync"
)

type Permit struct {
	budget *Budget
	key    [sha256.Size]byte
	entry  *entry
	once   sync.Once
}

// Finish charges invalid, blocked or ambiguous started work; successful and
// proven-not-started work release the reservation without starting a window.
func (p *Permit) Finish(charge bool) {
	if p == nil {
		return
	}
	p.once.Do(func() {
		b := p.budget
		b.mu.Lock()
		defer b.mu.Unlock()
		e := p.entry
		e.pending--
		now := b.config.Now()
		if charge {
			b.outcomes.WithLabelValues("charged").Inc()
			if e.reset.IsZero() || !now.Before(e.reset) {
				e.failures = 0
				e.reset = now.Add(b.config.Window)
				heap.Push(&b.expires, expiry{key: p.key, entry: e, reset: e.reset})
			}
			e.failures++
		} else {
			b.outcomes.WithLabelValues("released").Inc()
		}
		if e.pending == 0 && (e.failures == 0 || !now.Before(e.reset)) && b.entries[p.key] == e {
			delete(b.entries, p.key)
		}
	})
}
