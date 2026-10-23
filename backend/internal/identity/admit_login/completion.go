package admitlogin

import (
	"crypto/sha256"
	"sync"
)

type Outcome string

const (
	Success        Outcome = "success"
	Invalid        Outcome = "invalid"
	Blocked        Outcome = "blocked"
	Infrastructure Outcome = "infrastructure"
	Cancelled      Outcome = "cancelled"
	// NotStarted is reserved for a context rejected before calling Login or the
	// shared KDF gate's typed ErrBusy. Neither path can have checked a password.
	NotStarted Outcome = "not_started"
)

type Reservation struct {
	budget *Budget
	key    [sha256.Size]byte
	entry  *entry
	once   sync.Once
}

// Complete releases the running reservation exactly once. Only proven
// not-started work is refunded; cancellation or ambiguous infrastructure errors
// after Login starts remain charged, preventing a disconnect/refund bypass.
func (reservation *Reservation) Complete(outcome Outcome) {
	if reservation == nil {
		return
	}
	reservation.once.Do(func() {
		switch outcome {
		case Success, Invalid, Blocked, Infrastructure, Cancelled, NotStarted:
		default:
			outcome = Infrastructure
		}
		budget := reservation.budget
		budget.mutex.Lock()
		defer budget.mutex.Unlock()
		reservation.entry.inFlight--
		budget.inFlight--
		if outcome == NotStarted {
			reservation.entry.used--
		}
		budget.outcomes.WithLabelValues(string(outcome)).Inc()
		if reservation.entry.inFlight == 0 && !budget.config.Now().Before(reservation.entry.reset) {
			if budget.entries[reservation.key] == reservation.entry {
				delete(budget.entries, reservation.key)
			}
		}
	})
}
