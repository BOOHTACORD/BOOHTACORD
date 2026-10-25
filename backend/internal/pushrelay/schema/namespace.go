package relayschema

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

var ErrNamespace = errors.New("relay database belongs to another provider namespace")

type NamespaceDatabase interface {
	QueryRow(context.Context, string, ...any) pgx.Row
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
}

func BindNamespace(ctx context.Context, database NamespaceDatabase, namespace string) error {
	if namespace != "staging" && namespace != "production" {
		return ErrNamespace
	}
	if _, err := database.Exec(ctx, `CREATE TABLE IF NOT EXISTS relay_namespace(singleton boolean PRIMARY KEY CHECK(singleton),namespace text NOT NULL CHECK(namespace IN('staging','production')))`); err != nil {
		return err
	}
	var stored string
	err := database.QueryRow(ctx, `INSERT INTO relay_namespace(singleton,namespace)VALUES(true,$1)ON CONFLICT(singleton)DO UPDATE SET namespace=relay_namespace.namespace RETURNING namespace`, namespace).Scan(&stored)
	if err != nil {
		return err
	}
	if stored != namespace {
		return ErrNamespace
	}
	return nil
}
