package supportbridge

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
)

func (w Worker) Tick(ctx context.Context) error {
	var enabled bool
	if err := w.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM support_contact_configuration WHERE mode='product') OR EXISTS(SELECT 1 FROM support_public_routes)`).Scan(&enabled); err != nil {
		return ErrGateway
	}
	if !enabled {
		return nil
	}
	connection, err := w.db.Acquire(ctx)
	if err != nil {
		return ErrGateway
	}
	defer connection.Release()
	var locked bool
	if err = connection.QueryRow(ctx, `SELECT pg_try_advisory_lock(3360056)`).Scan(&locked); err != nil || !locked {
		return nil
	}
	defer func() {
		unlock, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		if _, err := connection.Exec(unlock, `SELECT pg_advisory_unlock(3360056)`); err != nil {
			connection.Conn().Close(unlock)
		}
	}()
	var status struct {
		Version    int    `json:"notice_version"`
		Public     bool   `json:"public"`
		Repository string `json:"repository"`
	}
	if err = w.client.request(ctx, "GET", "/status", nil, &status); err != nil {
		return err
	}
	if status.Version < 1 || status.Version > 1000000 || status.Repository != "BOOHTACORD/BOOHTACORD" {
		return ErrGateway
	}
	if _, err = w.db.Exec(ctx, `UPDATE support_product_identity SET notice_version=GREATEST(notice_version,$1),repository_public=$2 WHERE singleton=true`, status.Version, status.Public); err != nil {
		return ErrGateway
	}
	job, err := next(ctx, w.db)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return ErrGateway
	}
	if err == nil {
		if err = w.publish(ctx, job); err != nil {
			return err
		}
	}
	return w.receive(ctx)
}
