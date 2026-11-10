package coordinateroster

// RetryOnNextRefresh allows the next scheduled read to resend unchanged state.
// It does not schedule work, so a failing recipient cannot trigger a hot loop.
func (s *Subscription) RetryOnNextRefresh() bool {
	if s == nil || s.owner == nil || s.account == nil {
		return false
	}
	c := s.owner
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed || c.accounts[s.account.id] != s.account {
		return false
	}
	if _, ok := s.account.subs[s]; !ok {
		return false
	}
	s.retryNext = true
	return true
}
