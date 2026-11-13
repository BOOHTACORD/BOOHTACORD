package pool

import "github.com/jackc/pgx/v5/pgxpool"

func (m *Metrics) snapshot() map[string]float64 {
	values := make(map[string]float64)
	for _, pool := range []*pgxpool.Pool{m.pool, m.sessionPool} {
		if pool == nil {
			continue
		}
		s := pool.Stat()
		values["acquired"] += float64(s.AcquiredConns())
		values["idle"] += float64(s.IdleConns())
		values["total"] += float64(s.TotalConns())
		values["max"] += float64(s.MaxConns())
		values["constructing"] += float64(s.ConstructingConns())
		values["empty_acquires_total"] += float64(s.EmptyAcquireCount())
		values["empty_acquire_wait_seconds_total"] += s.EmptyAcquireWaitTime().Seconds()
		values["canceled_acquires_total"] += float64(s.CanceledAcquireCount())
	}
	return values
}
