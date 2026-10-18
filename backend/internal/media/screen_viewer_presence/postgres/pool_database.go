package postgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type PoolDatabase struct{ pool *pgxpool.Pool }

func NewPoolDatabase(pool *pgxpool.Pool) PoolDatabase { return PoolDatabase{pool: pool} }

func (database PoolDatabase) QueryRow(ctx context.Context, query string, arguments ...any) Row {
	return database.pool.QueryRow(ctx, query, arguments...)
}
