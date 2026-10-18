package memory

import (
	"errors"
	"sort"
	"sync"
	"time"

	presence "voice-platform/backend/internal/media/screen_viewer_presence"
)

const (
	PresenceTTL = 20 * time.Second
	MaxEntries  = 4096
)

var ErrClosed = errors.New("screen viewer presence store is closed")

type key struct{ ownerLeaseID, viewerLeaseID string }
type entry struct {
	ownerAccountID, viewerAccountID, trackSID string
	lastSeen                                  time.Time
	timer                                     *time.Timer
}

type Store struct {
	mu       sync.Mutex
	entries  map[key]*entry
	now      func() time.Time
	ttl      time.Duration
	capacity int
	changed  func(ownerAccountID string)
	closed   bool
}

func New(changed func(ownerAccountID string)) *Store {
	return newStore(time.Now, PresenceTTL, MaxEntries, changed)
}

func newStore(now func() time.Time, ttl time.Duration, capacity int, changed func(ownerAccountID string)) *Store {
	return &Store{entries: make(map[key]*entry), now: now, ttl: ttl, capacity: capacity, changed: changed}
}

func (store *Store) Watching(ownerLeaseID, viewerLeaseID, trackSID string) bool {
	store.mu.Lock()
	defer store.mu.Unlock()
	current := store.entries[key{ownerLeaseID, viewerLeaseID}]
	return current != nil && current.trackSID == trackSID && store.now().Sub(current.lastSeen) < store.ttl
}

func (store *Store) Watch(ownerLeaseID, ownerAccountID, viewerLeaseID, viewerAccountID, trackSID string) (bool, error) {
	store.mu.Lock()
	if store.closed {
		store.mu.Unlock()
		return false, ErrClosed
	}
	currentKey := key{ownerLeaseID, viewerLeaseID}
	current := store.entries[currentKey]
	if current == nil && len(store.entries) >= store.capacity {
		store.mu.Unlock()
		return false, presence.ErrCapacity
	}
	now := store.now()
	changed := current == nil || current.trackSID != trackSID || current.viewerAccountID != viewerAccountID || now.Sub(current.lastSeen) >= store.ttl
	if current == nil {
		current = &entry{}
		store.entries[currentKey] = current
	}
	if current.timer != nil {
		current.timer.Stop()
	}
	current.ownerAccountID, current.viewerAccountID, current.trackSID, current.lastSeen = ownerAccountID, viewerAccountID, trackSID, now
	current.timer = time.AfterFunc(store.ttl, func() { store.expire(currentKey, current) })
	store.mu.Unlock()
	return changed, nil
}

func (store *Store) Unwatch(ownerLeaseID, viewerLeaseID, trackSID string) bool {
	store.mu.Lock()
	currentKey := key{ownerLeaseID, viewerLeaseID}
	current := store.entries[currentKey]
	if current != nil && current.trackSID == trackSID {
		delete(store.entries, currentKey)
		if current.timer != nil {
			current.timer.Stop()
		}
	} else {
		current = nil
	}
	store.mu.Unlock()
	if current != nil {
		return true
	}
	return false
}

func (store *Store) Viewers(ownerLeaseID, trackSID string) []string {
	store.mu.Lock()
	now := store.now()
	viewerIDs := make(map[string]struct{})
	var expiredOwners []string
	for currentKey, current := range store.entries {
		if now.Sub(current.lastSeen) >= store.ttl {
			delete(store.entries, currentKey)
			if current.timer != nil {
				current.timer.Stop()
			}
			expiredOwners = append(expiredOwners, current.ownerAccountID)
			continue
		}
		if currentKey.ownerLeaseID == ownerLeaseID && current.trackSID == trackSID {
			viewerIDs[current.viewerAccountID] = struct{}{}
		}
	}
	store.mu.Unlock()
	for _, owner := range expiredOwners {
		store.notify(owner)
	}
	result := make([]string, 0, len(viewerIDs))
	for viewerID := range viewerIDs {
		result = append(result, viewerID)
	}
	sort.Strings(result)
	return result
}

func (store *Store) Clear(ownerLeaseID, trackSID string) bool {
	store.mu.Lock()
	var changedOwners []string
	for currentKey, current := range store.entries {
		if currentKey.ownerLeaseID != ownerLeaseID || trackSID != "" && current.trackSID != trackSID {
			continue
		}
		delete(store.entries, currentKey)
		if current.timer != nil {
			current.timer.Stop()
		}
		changedOwners = append(changedOwners, current.ownerAccountID)
	}
	store.mu.Unlock()
	return len(changedOwners) > 0
}

func (store *Store) Close() error {
	store.mu.Lock()
	defer store.mu.Unlock()
	if store.closed {
		return nil
	}
	store.closed = true
	for _, current := range store.entries {
		if current.timer != nil {
			current.timer.Stop()
		}
	}
	clear(store.entries)
	return nil
}

func (store *Store) expire(currentKey key, expected *entry) {
	store.mu.Lock()
	current := store.entries[currentKey]
	if store.closed || current != expected {
		store.mu.Unlock()
		return
	}
	remaining := store.ttl - store.now().Sub(current.lastSeen)
	if remaining > 0 {
		current.timer = time.AfterFunc(remaining, func() { store.expire(currentKey, expected) })
		store.mu.Unlock()
		return
	}
	delete(store.entries, currentKey)
	owner := current.ownerAccountID
	store.mu.Unlock()
	store.notify(owner)
}

func (store *Store) notify(ownerAccountID string) {
	if store.changed != nil && ownerAccountID != "" {
		store.changed(ownerAccountID)
	}
}
