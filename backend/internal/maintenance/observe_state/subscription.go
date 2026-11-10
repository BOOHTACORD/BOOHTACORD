package observestate

import "sync"

type Subscription struct {
	observer    *Observer
	events      chan State
	minSequence uint64
	initialized bool
	once        sync.Once
}

// Subscribe registers before requesting its initial authoritative read.
func (o *Observer) Subscribe() *Subscription {
	o.mu.Lock()
	s := &Subscription{observer: o, events: make(chan State, 1), minSequence: o.sequence + 1}
	if o.closed {
		close(s.events)
		o.mu.Unlock()
		return s
	}
	o.subscribers[s] = struct{}{}
	o.mu.Unlock()
	o.RequestRefresh()
	return s
}

func (s *Subscription) Events() <-chan State { return s.events }

func (s *Subscription) Close() {
	s.once.Do(func() {
		s.observer.mu.Lock()
		defer s.observer.mu.Unlock()
		if _, ok := s.observer.subscribers[s]; ok {
			delete(s.observer.subscribers, s)
			select {
			case <-s.events:
			default:
			}
			close(s.events)
		}
	})
}

func (o *Observer) shutdown() {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.closed = true
	for sub := range o.subscribers {
		delete(o.subscribers, sub)
		select {
		case <-sub.events:
		default:
		}
		close(sub.events)
	}
}

func (o *Observer) apply(sequence uint64, active, known bool) {
	o.mu.Lock()
	defer o.mu.Unlock()
	changed := !o.hasState || known != o.state.Known || (known && active != o.state.Active)
	if changed {
		o.state.Revision++
		o.state.Known = known
		if known {
			o.state.Active = active
		}
		o.hasState = true
	}
	for sub := range o.subscribers {
		if sub.minSequence > sequence {
			continue
		}
		if !sub.initialized || changed {
			sub.initialized = true
			select {
			case <-sub.events:
			default:
			}
			sub.events <- o.state
		}
	}
}
