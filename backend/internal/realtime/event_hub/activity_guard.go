package eventhub

import (
	"hash/fnv"
	"sync"
	"time"
)

func (hub *Hub) activityGuard(accountID string) *sync.Mutex {
	hash := fnv.New32a()
	_, _ = hash.Write([]byte(accountID))
	return &hub.activityGuards[hash.Sum32()%uint32(len(hub.activityGuards))]
}

// IfInactive serializes an AFK commit with changes to this account's activity
// and connections. The callback must not call back into account activity.
func (hub *Hub) IfInactive(accountID string, cutoff time.Time, commit func() error) (bool, error) {
	if hub == nil || accountID == "" || commit == nil {
		return false, nil
	}
	guard := hub.activityGuard(accountID)
	guard.Lock()
	defer guard.Unlock()
	last, connected := hub.LastActivity(accountID)
	if !connected || last.After(cutoff) {
		return false, nil
	}
	if err := commit(); err != nil {
		return false, err
	}
	return true, nil
}
