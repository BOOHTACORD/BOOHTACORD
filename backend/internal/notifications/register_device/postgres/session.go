package registerdevicepostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/session"
	d "voice-platform/backend/internal/notifications/register_device"
)

const lockIssuingSession = `SELECT 1 FROM sessions s JOIN users u ON u.id=s.user_id
 WHERE s.token_digest=$1 AND s.user_id=$2::uuid AND s.revoked_at IS NULL
 AND s.expires_at>now() AND s.last_active_at>now()-($3::double precision*interval '1 second')
 AND u.blocked_at IS NULL FOR SHARE OF s,u`

func lockSession(ctx context.Context, tx pgx.Tx, r d.Record) error {
	var found int
	err := tx.QueryRow(ctx, lockIssuingSession, r.SessionDigest[:], r.AccountID, int64(session.IdleLifetime.Seconds())).Scan(&found)
	if errors.Is(err, pgx.ErrNoRows) {
		return d.ErrUnauthorized
	}
	return err
}

const revokeStaleDestination = `UPDATE notification_devices d SET state='revoked',generation=LEAST(generation+1,1000000000),updated_at=now()
 WHERE d.installation_id=$1::uuid AND d.state IN('registering','active') AND
 NOT EXISTS(SELECT 1 FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_digest=d.session_digest
 AND s.revoked_at IS NULL AND s.expires_at>now() AND s.last_active_at>now()-($2::double precision*interval '1 second') AND u.blocked_at IS NULL)`

func admit(ctx context.Context, tx pgx.Tx, r d.Record, creating bool) error {
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended('notification-devices/'||$1,0))`, r.InstallationID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, revokeStaleDestination, r.InstallationID, int64(session.IdleLifetime.Seconds())); err != nil {
		return err
	}
	var accountCount, installationCount, recent, accountTotal, installationTotal int
	err := tx.QueryRow(ctx, `SELECT
 count(*) FILTER(WHERE account_id=$1::uuid AND state IN('active','registering') AND expires_at>now()),
 count(*) FILTER(WHERE state IN('active','registering') AND expires_at>now()),
 count(*) FILTER(WHERE account_id=$1::uuid AND created_at>now()-interval '1 minute'),
 count(*) FILTER(WHERE account_id=$1::uuid),count(*)
 FROM notification_devices WHERE installation_id=$2::uuid AND id<>$3::uuid`, r.AccountID, r.InstallationID, r.ID).Scan(&accountCount, &installationCount, &recent, &accountTotal, &installationTotal)
	if err != nil {
		return err
	}
	if accountCount >= 10 || installationCount >= 1000 || creating && (recent >= 5 || accountTotal >= 100 || installationTotal >= 10000) {
		return d.ErrLimit
	}
	return nil
}
