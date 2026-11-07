package trackloginfailures

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

func (a expirations) Len() int           { return len(a) }
func (a expirations) Less(i, j int) bool { return a[i].reset.Before(a[j].reset) }
func (a expirations) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a *expirations) Push(x any)        { *a = append(*a, x.(expiry)) }
func (a *expirations) Pop() any {
	old := *a
	n := len(old)
	value := old[n-1]
	old[n-1] = expiry{}
	*a = old[:n-1]
	return value
}
func (b *Budget) prune(now time.Time, limit int) {
	for limit > 0 && len(b.expires) > 0 && !now.Before(b.expires[0].reset) {
		x := heap.Pop(&b.expires).(expiry)
		if b.entries[x.key] == x.entry && x.entry.reset.Equal(x.reset) && x.entry.pending == 0 {
			delete(b.entries, x.key)
		}
		limit--
	}
}
