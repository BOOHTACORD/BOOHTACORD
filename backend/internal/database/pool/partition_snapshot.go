package pool

import "github.com/jackc/pgx/v5/pgxpool"

type partitionSnapshot struct {
	name string
	pool *pgxpool.Pool
}

func (m *Metrics) partitions() []partitionSnapshot {
	if m.pool == nil {
		return nil
	}
	if m.sessionPool == nil {
		return []partitionSnapshot{{"shared", m.pool}}
	}
	return []partitionSnapshot{{"main", m.pool}, {"session", m.sessionPool}}
}

func partitionValues(pool *pgxpool.Pool) map[string]float64 {
	s := pool.Stat()
	return map[string]float64{"acquired": float64(s.AcquiredConns()), "idle": float64(s.IdleConns()),
		"total": float64(s.TotalConns()), "max": float64(s.MaxConns()), "constructing": float64(s.ConstructingConns())}
}
