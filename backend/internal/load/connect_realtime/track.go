package connect_realtime

import (
	"errors"
	"sync"
)

// Track pins an expected delivery until its owner releases it. Pins are bound
// to the current socket generation and never exceed the delivery cache bound.
func (s *Socket) Track(id string) (func(), error) {
	s.mu.Lock()
	if id == "" || s.conn == nil || s.failure {
		s.mu.Unlock()
		return nil, errors.New("cannot track delivery on unavailable socket")
	}
	if s.tracked[id] == 0 && len(s.tracked) >= 512 {
		s.mu.Unlock()
		return nil, errors.New("too many pending deliveries")
	}
	s.tracked[id]++
	generation := s.generation
	s.mu.Unlock()
	var once sync.Once
	return func() {
		once.Do(func() {
			s.mu.Lock()
			defer s.mu.Unlock()
			if s.generation != generation {
				return
			}
			if s.tracked[id] <= 1 {
				delete(s.tracked, id)
			} else {
				s.tracked[id]--
			}
		})
	}, nil
}
