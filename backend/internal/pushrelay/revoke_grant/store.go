package revokegrant

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
	signature "voice-platform/backend/internal/pushrelay/request_signature"
)

var ErrNotFound = errors.New("relay grant unavailable")

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Store struct{ Database Database }

func (s Store) Revoke(ctx context.Context, request signature.Request, grant string, now time.Time) error {
	if !receipt.ID(grant) || request.Method != "DELETE" || request.Path != "/v1/grants/"+grant {
		return ErrNotFound
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.Database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() {
		clean, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		_ = tx.Rollback(clean)
	}()
	if _, err = auth.Lock(ctx, tx); err != nil {
		return err
	}
	// Revocation remains available even while sending is killed.
	if err = auth.Verify(ctx, tx, request, "device", false, now); err != nil {
		return err
	}
	changed, err := tx.Exec(ctx, `UPDATE relay_grants SET state='revoked' WHERE id=$1::uuid AND device_id=$2::uuid`, grant, request.Subject)
	if err != nil {
		return err
	}
	if changed.RowsAffected() != 1 {
		return ErrNotFound
	}
	changed, err = tx.Exec(ctx, `UPDATE relay_jobs SET state='revoked',lease_owner=NULL,lease_until=NULL WHERE grant_id=$1::uuid AND state IN('pending','claimed','retry')`, grant)
	if err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_policy SET pending=pending-$1 WHERE singleton`, changed.RowsAffected()); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
