package runrostermatrix

import (
	"math"
	"sort"
	"sync"
	"time"
)

type Summary struct {
	Count               int
	P50MS, P95MS, P99MS float64
}
type Measurements struct {
	mu            sync.Mutex
	seen          [][4]bool
	values        [4][]float64
	required      [4]bool
	changeStarted time.Time
}

func NewMeasurements(accounts int) *Measurements {
	if accounts < 1 || accounts > 100 {
		accounts = 0
	}
	return &Measurements{seen: make([][4]bool, accounts), required: [4]bool{true, true, true, false}}
}

func NewPublicMeasurements(guests int, candidate bool) *Measurements {
	measurements := NewMeasurements(guests)
	measurements.required = [4]bool{candidate, false, true, false}
	return measurements
}

func (m *Measurements) Observe(index int, kind string, elapsed time.Duration) {
	domain := -1
	switch kind {
	case "ready":
		domain = 0
	case "roster":
		domain = 1
	case "maintenance":
		domain = 2
	case "maintenance_change":
		domain = 3
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if index < 0 || index >= len(m.seen) || domain < 0 || elapsed < 0 || m.seen[index][domain] {
		return
	}
	if domain == 3 {
		if m.changeStarted.IsZero() {
			return
		}
		elapsed = time.Since(m.changeStarted)
	}
	m.seen[index][domain] = true
	m.values[domain] = append(m.values[domain], float64(elapsed)/float64(time.Millisecond))
}

func (m *Measurements) Complete() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	if len(m.seen) == 0 {
		return false
	}
	for _, seen := range m.seen {
		for index, required := range m.required {
			if required && !seen[index] {
				return false
			}
		}
	}
	return true
}

func (m *Measurements) Snapshot() map[string]Summary {
	m.mu.Lock()
	defer m.mu.Unlock()
	result := make(map[string]Summary, 4)
	for i, name := range []string{"ready", "roster", "maintenance", "maintenance_change"} {
		values := append([]float64(nil), m.values[i]...)
		sort.Float64s(values)
		q := func(p float64) float64 {
			if len(values) == 0 {
				return 0
			}
			return values[int(math.Ceil(float64(len(values))*p))-1]
		}
		result[name] = Summary{len(values), q(.5), q(.95), q(.99)}
	}
	return result
}

func summarizeMessages(values []float64) Summary {
	sort.Float64s(values)
	q := func(p float64) float64 {
		if len(values) == 0 {
			return 0
		}
		return values[int(math.Ceil(float64(len(values))*p))-1]
	}
	return Summary{len(values), q(.5), q(.95), q(.99)}
}
