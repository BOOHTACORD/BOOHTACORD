package coordinateroster

// Current rejects states invalidated since their read or issued to another account.
// It does not replace session/ACL checks and must not wrap network writes.
func (s *Subscription) Current(state State) bool {
	c := s.owner
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed || c.accounts[s.account.id] != s.account || state.owner != s.account {
		return false
	}
	if _, ok := s.account.subs[s]; !ok || !s.initialized {
		return false
	}
	return state.Generation == c.generation && state.epoch == s.account.epoch && state.Revision == s.account.revision
}
