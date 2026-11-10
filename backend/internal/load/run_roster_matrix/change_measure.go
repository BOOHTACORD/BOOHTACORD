package runrostermatrix

import (
	"errors"
	"time"
)

func (m *Measurements) StartMaintenanceChange(started time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if !m.changeStarted.IsZero() || started.IsZero() || started.After(time.Now()) {
		return errors.New("invalid maintenance change start")
	}
	m.changeStarted = started
	return nil
}

func (m *Measurements) ChangeComplete() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.changeStarted.IsZero() || len(m.seen) == 0 {
		return false
	}
	for _, seen := range m.seen {
		if !seen[3] {
			return false
		}
	}
	return true
}
