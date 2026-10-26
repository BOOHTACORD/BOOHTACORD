package revokedevice

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	d "voice-platform/backend/internal/notifications/register_device"
)

var ErrNotFound = errors.New("notification device unavailable")

type Database interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}
type Store struct {
	database             Database
	origin, installation string
}

func New(database Database, origin, installation string) Store {
	return Store{database, origin, installation}
}
func (s Store) Revoke(ctx context.Context, actor, id string, expected int64) error {
	if expected < 1 || expected > 1000000000 {
		return d.ErrInvalid
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	var generation int64
	err := s.database.QueryRow(ctx, `UPDATE notification_devices SET state='revoked',generation=LEAST(generation+1,1000000000),updated_at=now()
 WHERE id=$1::uuid AND account_id=$2::uuid AND origin=$3 AND installation_id=$4::uuid AND generation=$5
 RETURNING generation`, id, actor, s.origin, s.installation, expected).Scan(&generation)
	if err == nil {
		return nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	var state string
	err = s.database.QueryRow(ctx, `SELECT state,generation FROM notification_devices WHERE id=$1::uuid AND account_id=$2::uuid AND origin=$3 AND installation_id=$4::uuid`, id, actor, s.origin, s.installation).Scan(&state, &generation)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if state == "revoked" && generation == expected+1 {
		return nil
	}
	return d.ErrConflict
}
