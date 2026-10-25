package registerdevicepostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	d "voice-platform/backend/internal/notifications/register_device"
)

func existing(ctx context.Context, tx pgx.Tx, r d.Record) (d.Record, bool, error) {
	var fingerprint, registration []byte
	err := tx.QueryRow(ctx, `SELECT id::text,generation,state,permission,expires_at,secret_cipher,fingerprint,registration_hash,nonce_digest,enrollment_until,consent_at,created_at,updated_at
 FROM notification_devices WHERE installation_id=$1::uuid AND origin=$2 AND instance_id=$3::uuid AND transport=$4 AND namespace=$5
 AND account_id=$6::uuid AND session_digest=$7 FOR UPDATE`, r.InstallationID, r.Origin, r.InstanceID, r.Transport, r.Namespace, r.AccountID, r.SessionDigest[:]).Scan(&r.ID, &r.Generation, &r.State, &r.Permission, &r.ExpiresAt, &r.SecretCipher, &fingerprint, &registration, &r.NonceDigest, &r.EnrollmentUntil, &r.ConsentAt, &r.CreatedAt, &r.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return r, false, nil
	}
	if err != nil {
		return r, false, err
	}
	if len(fingerprint) != 32 || len(registration) != 32 {
		return r, false, d.ErrUnavailable
	}
	copy(r.Fingerprint[:], fingerprint)
	copy(r.RegistrationHash[:], registration)
	return r, true, nil
}
