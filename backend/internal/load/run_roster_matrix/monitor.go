package runrostermatrix

import (
	"context"
	"sync"
	"time"

	"voice-platform/backend/internal/load/observe_resources"
)

type monitor struct {
	mu      sync.Mutex
	samples []observe_resources.Snapshot
	failed  bool
}

func (m *monitor) run(ctx context.Context, cancel context.CancelFunc, guard observe_resources.Guard) {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			sample, err := guard.Check(ctx)
			if ctx.Err() != nil {
				return
			}
			m.mu.Lock()
			if err != nil || sample.MetricsStatus != "AVAILABLE" {
				m.failed = true
			} else if len(m.samples) < 128 {
				m.samples = append(m.samples, sample)
			}
			failed := m.failed
			m.mu.Unlock()
			if failed {
				cancel()
				return
			}
		}
	}
}

func (m *monitor) result() ([]observe_resources.Snapshot, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]observe_resources.Snapshot(nil), m.samples...), m.failed
}
