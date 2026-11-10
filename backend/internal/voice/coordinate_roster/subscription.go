package coordinateroster

import (
	"strings"
	"sync"

	"github.com/google/uuid"
)

type Subscription struct {
	owner       *Coordinator
	account     *account
	events      chan State
	initialized bool
	retryNext   bool
	once        sync.Once
}

// Subscribe registers before requesting a fresh authoritative snapshot.
func (c *Coordinator) Subscribe(id string) (*Subscription, error) {
	parsed, err := uuid.Parse(id)
	if err != nil || parsed.String() != strings.ToLower(id) {
		return nil, ErrAdmission
	}
	id = parsed.String()
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed || c.subscribers >= c.config.MaxSubscribers {
		return nil, ErrAdmission
	}
	a := c.accounts[id]
	if a == nil {
		if len(c.accounts) >= c.config.MaxAccounts {
			return nil, ErrAdmission
		}
		a = &account{id: id, subs: make(map[*Subscription]struct{})}
		c.accounts[id] = a
	}
	sub := &Subscription{owner: c, account: a, events: make(chan State, 1)}
	a.subs[sub] = struct{}{}
	c.subscribers++
	a.epoch++
	a.dirty = true
	c.schedule(a)
	return sub, nil
}

func (s *Subscription) Events() <-chan State { return s.events }

// RequestRefresh discards queued state and requests a fresh read for this recipient.
func (s *Subscription) RequestRefresh() bool {
	c := s.owner
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed || c.accounts[s.account.id] != s.account {
		return false
	}
	if _, ok := s.account.subs[s]; !ok {
		return false
	}
	select {
	case <-s.events:
	default:
	}
	s.initialized = false
	s.account.epoch++
	s.account.dirty = true
	if s.account.cancel != nil {
		s.account.cancel()
	}
	c.schedule(s.account)
	return true
}

func (s *Subscription) Close() {
	s.once.Do(func() {
		c := s.owner
		c.mu.Lock()
		defer c.mu.Unlock()
		if _, ok := s.account.subs[s]; !ok {
			return
		}
		delete(s.account.subs, s)
		c.subscribers--
		select {
		case <-s.events:
		default:
		}
		close(s.events)
		if len(s.account.subs) == 0 && c.accounts[s.account.id] == s.account {
			if s.account.cancel != nil {
				s.account.cancel()
			}
			delete(c.accounts, s.account.id)
		}
	})
}

func (c *Coordinator) shutdown() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.closed = true
	for _, a := range c.accounts {
		for sub := range a.subs {
			delete(a.subs, sub)
			select {
			case <-sub.events:
			default:
			}
			close(sub.events)
		}
	}
	clear(c.accounts)
	c.subscribers = 0
}
