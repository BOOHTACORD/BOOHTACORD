package admitlogin

import (
	"container/heap"
	"crypto/sha256"
	"time"
)

type expiry struct {
	key   [sha256.Size]byte
	entry *entry
	reset time.Time
}
type expirations []expiry

func (items expirations) Len() int           { return len(items) }
func (items expirations) Less(i, j int) bool { return items[i].reset.Before(items[j].reset) }
func (items expirations) Swap(i, j int)      { items[i], items[j] = items[j], items[i] }
func (items *expirations) Push(value any)    { *items = append(*items, value.(expiry)) }
func (items *expirations) Pop() any {
	old := *items
	last := old[len(old)-1]
	old[len(old)-1] = expiry{}
	*items = old[:len(old)-1]
	return last
}
func (budget *Budget) prune(now time.Time, limit int) {
	for limit > 0 && len(budget.expires) > 0 && !now.Before(budget.expires[0].reset) {
		candidate := heap.Pop(&budget.expires).(expiry)
		if budget.entries[candidate.key] == candidate.entry && candidate.entry.inFlight == 0 {
			delete(budget.entries, candidate.key)
		}
		// Running expired entries stay in the bounded map. Complete removes them
		// after actual work returns; no expiry timer or detached goroutine is needed.
		limit--
	}
}
