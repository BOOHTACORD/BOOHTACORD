package connect_realtime

// Failed reports whether the current socket has stopped delivering events.
func (s *Socket) Failed() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.failure
}
