package listdevices

import (
	"context"
	"github.com/jackc/pgx/v5"
	"time"
	"voice-platform/backend/internal/identity/session"
	d "voice-platform/backend/internal/notifications/register_device"
)

type Database interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
}
type Store struct {
	database             Database
	origin, installation string
}

func New(database Database, origin, installation string) Store {
	return Store{database, origin, installation}
}
func (s Store) List(ctx context.Context, actor string) ([]d.Record, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	rows, err := s.database.Query(ctx, `SELECT d.id::text,d.instance_id::text,d.transport,d.namespace,d.generation,
 CASE WHEN ss.revoked_at IS NOT NULL OR ss.expires_at<=now() OR ss.last_active_at<=now()-($4::double precision*interval '1 second') THEN 'revoked'
 WHEN d.expires_at<=now() OR (d.state='registering' AND d.enrollment_until<=now()) THEN 'stale' ELSE d.state END,d.permission,d.expires_at,d.consent_at,d.created_at,d.session_digest
 FROM notification_devices d JOIN sessions ss ON ss.token_digest=d.session_digest
 WHERE d.account_id=$1::uuid AND d.origin=$2 AND d.installation_id=$3::uuid ORDER BY d.updated_at DESC LIMIT 100`, actor, s.origin, s.installation, int64(session.IdleLifetime.Seconds()))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]d.Record, 0)
	for rows.Next() {
		r := d.Record{AccountID: actor, Origin: s.origin, InstallationID: s.installation}
		var digest []byte
		if err = rows.Scan(&r.ID, &r.InstanceID, &r.Transport, &r.Namespace, &r.Generation, &r.State, &r.Permission, &r.ExpiresAt, &r.ConsentAt, &r.CreatedAt, &digest); err != nil {
			return nil, err
		}
		if len(digest) != 32 {
			return nil, d.ErrUnavailable
		}
		copy(r.SessionDigest[:], digest)
		r.SessionRef = d.SessionReference(r.SessionDigest)
		result = append(result, r)
	}
	return result, rows.Err()
}
