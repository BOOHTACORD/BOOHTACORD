package revokegrant

import (
	"context"
	"crypto/ed25519"
	"github.com/jackc/pgx/v5"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
	signature "voice-platform/backend/internal/pushrelay/request_signature"
)

func (s Store) Device(ctx context.Context, request signature.Request, now time.Time) error {
	if request.Role != "device" || request.Method != "DELETE" || request.Path != "/v1/devices/"+request.Subject {
		return ErrNotFound
	}
	if _, err := signature.Canonical(request); err != nil {
		return auth.ErrDenied
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
	var public []byte
	var state string
	if err = tx.QueryRow(ctx, `SELECT public_key,state FROM relay_devices WHERE id=$1::uuid FOR UPDATE`, request.Subject).Scan(&public, &state); err != nil {
		return ErrNotFound
	}
	if signature.Verify(ed25519.PublicKey(public), request, now) != nil {
		return auth.ErrDenied
	}
	if state == "revoked" {
		return tx.Commit(ctx)
	}
	if err = auth.Verify(ctx, tx, request, "device", true, now); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_devices SET state='revoked',generation=generation+1,updated_at=$2 WHERE id=$1::uuid`, request.Subject, now); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_grants SET state='revoked' WHERE device_id=$1::uuid AND state='active'`, request.Subject); err != nil {
		return err
	}
	changed, err := tx.Exec(ctx, `UPDATE relay_jobs SET state='revoked',lease_owner=NULL,lease_until=NULL WHERE device_id=$1::uuid AND state IN('pending','claimed','retry')`, request.Subject)
	if err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_policy SET pending=pending-$1 WHERE singleton`, changed.RowsAffected()); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
