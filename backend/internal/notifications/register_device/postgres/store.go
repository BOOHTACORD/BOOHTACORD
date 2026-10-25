package registerdevicepostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"time"
	d "voice-platform/backend/internal/notifications/register_device"
)

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Store struct{ database Database }

func New(database Database) Store { return Store{database} }
func (s Store) Register(ctx context.Context, r d.Record, expected int64) (d.Record, error) {
	if r.Generation != expected+1 || expected < 0 || r.Generation > 1000000000 {
		return d.Record{}, d.ErrInvalid
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return d.Record{}, err
	}
	defer func() {
		cleanup, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		_ = tx.Rollback(cleanup)
	}()
	if err = lockSession(ctx, tx, r); err != nil {
		return d.Record{}, err
	}
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended('notification-devices/'||$1,0))`, r.InstallationID); err != nil {
		return d.Record{}, err
	}
	old, found, err := existing(ctx, tx, r)
	if err != nil {
		return d.Record{}, err
	}
	if found {
		if expected > 0 && old.ID != r.ID {
			return d.Record{}, d.ErrConflict
		}
		if old.Generation == expected+1 && old.RegistrationHash == r.RegistrationHash && (old.State == "active" || old.State == "registering") && old.ExpiresAt.After(time.Now()) && (old.State != "registering" || old.EnrollmentUntil != nil && old.EnrollmentUntil.After(time.Now())) {
			if err = tx.Commit(ctx); err != nil {
				return d.Record{}, err
			}
			return old, nil
		}
		if expected == 0 || old.Generation != expected {
			return d.Record{}, d.ErrConflict
		}
	}
	if err = admit(ctx, tx, r, expected == 0); err != nil {
		return d.Record{}, err
	}
	args := []any{r.ID, r.AccountID, r.SessionDigest[:], r.InstallationID, r.Origin, r.InstanceID, r.Transport, r.Namespace, r.Generation, r.State, r.Permission, r.SecretCipher, r.Fingerprint[:], r.NonceDigest, r.EnrollmentUntil, r.ExpiresAt, r.ConsentAt, r.CreatedAt, r.UpdatedAt, r.RegistrationHash[:]}
	query := insertDevice
	if expected > 0 {
		query = updateDevice
		args = append(args, expected)
	}
	err = tx.QueryRow(ctx, query, args...).Scan(&r.CreatedAt, &r.ConsentAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return d.Record{}, d.ErrConflict
	}
	var pgError *pgconn.PgError
	if errors.As(err, &pgError) && pgError.Code == "23505" {
		return d.Record{}, d.ErrConflict
	}
	if err != nil {
		return d.Record{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return d.Record{}, err
	}
	return r, nil
}
