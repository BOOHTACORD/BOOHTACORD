package record_results

import (
	"math"
	"sort"
	"sync"
	"time"
)

var allowed = map[string]bool{"nat_limit": true, "login": true, "session": true, "topology": true, "members": true, "history": true, "search": true, "message": true, "cursor": true, "lease": true, "credential": true, "release": true, "acl": true, "origin_acl": true, "upload": true, "download": true, "upload_limit": true, "logout": true, "revoked": true, "ws_ready": true, "ws_close": true, "ws_close_session_unavailable": true, "ws_close_resync_required": true, "ws_close_roster_unavailable": true, "ws_close_other": true, "fanout": true, "reconnect": true, "replay": true, "resync": true}

type Summary struct {
	Count, Errors       int
	P50MS, P95MS, P99MS float64
	Statuses            map[int]int
}
type sample struct {
	count, errors int
	latencies     []float64
	statuses      map[int]int
}
type Results struct {
	mu      sync.Mutex
	rows    map[string]*sample
	started time.Time
}

func New() *Results { return &Results{rows: map[string]*sample{}, started: time.Now()} }
func (r *Results) Observe(route string, status int, elapsed time.Duration) {
	r.ObserveOutcome(route, status, elapsed, status >= 200 && status < 400)
}
func (r *Results) ObserveOutcome(route string, status int, elapsed time.Duration, success bool) {
	if !allowed[route] {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	s := r.rows[route]
	if s == nil {
		s = &sample{statuses: map[int]int{}}
		r.rows[route] = s
	}
	s.count++
	s.statuses[status]++
	if !success {
		s.errors++
	}
	ms := float64(elapsed) / float64(time.Millisecond)
	// Last 6000 observations per route bound memory; quantiles are window estimates.
	if len(s.latencies) < 6000 {
		s.latencies = append(s.latencies, ms)
	} else {
		s.latencies[(s.count-1)%6000] = ms
	}
}
func (r *Results) Snapshot() map[string]Summary {
	r.mu.Lock()
	defer r.mu.Unlock()
	result := map[string]Summary{}
	for name, s := range r.rows {
		values := append([]float64{}, s.latencies...)
		sort.Float64s(values)
		q := func(p float64) float64 {
			if len(values) == 0 {
				return 0
			}
			return values[int(math.Ceil(p*float64(len(values))))-1]
		}
		statuses := map[int]int{}
		for k, v := range s.statuses {
			statuses[k] = v
		}
		result[name] = Summary{s.count, s.errors, q(.5), q(.95), q(.99), statuses}
	}
	return result
}
