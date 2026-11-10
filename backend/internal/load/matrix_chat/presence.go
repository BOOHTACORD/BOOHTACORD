package matrixchat

// ObservePresence counts an event without retaining its account identifier.
func (c *Collector) ObservePresence(index int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if index >= 0 && index < c.accounts {
		c.presence++
	}
}

func (c *Collector) PresenceCount() uint64 {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.presence
}
