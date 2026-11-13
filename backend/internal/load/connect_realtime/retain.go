package connect_realtime

import "time"

// Called under the socket lock. Evict the oldest untracked observation first.
func (s *Socket) remember(id string, at time.Time) bool {
	if _, exists := s.seen[id]; !exists {
		s.order = append(s.order, id)
	}
	s.seen[id] = at
	for len(s.seen) > 512 && len(s.order) > 0 {
		oldest := s.order[0]
		s.order = s.order[1:]
		if s.tracked[oldest] > 0 {
			s.order = append(s.order, oldest)
			continue
		}
		delete(s.seen, oldest)
	}
	return len(s.seen) <= 512
}
