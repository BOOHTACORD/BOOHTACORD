//go:build linux

package app

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

// These route-boundary tests do not authenticate or query PostgreSQL. The pool
// satisfies production's fail-closed wiring without opening a database session.
func routeTestPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	pool, err := pgxpool.New(context.Background(), "postgres://test@127.0.0.1:1/test?sslmode=disable")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	return pool
}
