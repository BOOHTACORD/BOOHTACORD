package pool

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// partitionConfigs reserves a bounded portion of the configured total for
// session lookups. A single connection remains shared for compatibility.
func partitionConfigs(original *pgxpool.Config) (*pgxpool.Config, *pgxpool.Config) {
	main := original.Copy()
	if original.MaxConns <= 1 {
		return main, nil
	}
	reserved := min(int32(4), max(int32(1), original.MaxConns/5))
	session := original.Copy()
	main.MaxConns, session.MaxConns = original.MaxConns-reserved, reserved
	main.MinConns = min(original.MinConns, main.MaxConns)
	session.MinConns = original.MinConns - main.MinConns
	main.MinIdleConns = min(original.MinIdleConns, main.MaxConns)
	session.MinIdleConns = original.MinIdleConns - main.MinIdleConns
	return main, session
}

// OpenPartitionedObserved preserves the configured connection budget while
// isolating session checks. Both pools contribute to the existing metrics.
func OpenPartitionedObserved(ctx context.Context, databaseURL string, metrics *Metrics) (*pgxpool.Pool, *pgxpool.Pool, error) {
	if databaseURL == "" {
		return nil, nil, ErrDatabaseURLRequired
	}
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, nil, fmt.Errorf("open postgres pool: %w", err)
	}
	if metrics != nil {
		config.ConnConfig.Tracer = metrics
	}
	mainConfig, sessionConfig := partitionConfigs(config)
	main, err := pgxpool.NewWithConfig(ctx, mainConfig)
	if err != nil {
		return nil, nil, fmt.Errorf("open postgres pool: %w", err)
	}
	if err := main.Ping(ctx); err != nil {
		main.Close()
		return nil, nil, fmt.Errorf("ping postgres: %w", err)
	}
	if sessionConfig == nil {
		if metrics != nil {
			metrics.pool = main
			metrics.startExport()
		}
		return main, main, nil
	}
	session, err := pgxpool.NewWithConfig(ctx, sessionConfig)
	if err != nil {
		main.Close()
		return nil, nil, fmt.Errorf("open session postgres pool: %w", err)
	}
	if err := session.Ping(ctx); err != nil {
		session.Close()
		main.Close()
		return nil, nil, fmt.Errorf("ping session postgres: %w", err)
	}
	if metrics != nil {
		metrics.pool, metrics.sessionPool = main, session
		metrics.startExport()
	}
	return main, session, nil
}
