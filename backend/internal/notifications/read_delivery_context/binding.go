package readdeliverycontext

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"time"
	"voice-platform/backend/internal/identity/session"
	d "voice-platform/backend/internal/notifications/register_device"
)

func (r Reader) Binding(ctx context.Context, id, account, origin, installation, namespace string, now time.Time) (d.Record, error) {
	out := d.Record{ID: id, AccountID: account, Origin: origin, InstallationID: installation, Namespace: namespace}
	if parsed, err := uuid.Parse(installation); err != nil || parsed == uuid.Nil {
		return out, ErrUnavailable
	}
	var digest []byte
	var active bool
	err := r.database.QueryRow(ctx, `SELECT d.instance_id::text,d.transport,d.generation,d.state,d.permission,d.expires_at,d.secret_cipher,d.consent_at,d.created_at,d.session_digest,
 s.user_id=d.account_id AND s.revoked_at IS NULL AND s.expires_at>$7 AND s.last_active_at>$7::timestamptz-($6::double precision*interval '1 second') AND u.blocked_at IS NULL
 FROM notification_devices d JOIN sessions s ON s.token_digest=d.session_digest JOIN users u ON u.id=d.account_id
 WHERE d.id=$1::uuid AND d.account_id=$2::uuid AND d.origin=$3 AND d.installation_id=$4::uuid AND d.namespace=$5`, id, account, origin, installation, namespace, int64(session.IdleLifetime.Seconds()), now).Scan(&out.InstanceID, &out.Transport, &out.Generation, &out.State, &out.Permission, &out.ExpiresAt, &out.SecretCipher, &out.ConsentAt, &out.CreatedAt, &digest, &active)
	if errors.Is(err, pgx.ErrNoRows) {
		return out, ErrUnavailable
	}
	if err != nil {
		return out, err
	}
	if len(digest) != 32 {
		return out, ErrUnavailable
	}
	copy(out.SessionDigest[:], digest)
	out.SessionRef = d.SessionReference(out.SessionDigest)
	if !active {
		out.State = "revoked"
	}
	return out, nil
}
