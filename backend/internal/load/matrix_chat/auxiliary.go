package matrixchat

// ObserveAuxiliary counts only fixed event classes without retaining identities.
func (c *Collector) ObserveAuxiliary(index int, kind string) {
	slot := -1
	switch kind {
	case "roster":
		slot = 0
	case "maintenance":
		slot = 1
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if index >= 0 && index < c.accounts && slot >= 0 {
		c.auxiliary[slot]++
	}
}

func (c *Collector) AuxiliaryCounts() [2]uint64 {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.auxiliary
}
