package activatedevice

import (
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"time"
	"voice-platform/backend/internal/identity/session"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	d "voice-platform/backend/internal/notifications/register_device"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
)

func (s Service) Activate(ctx context.Context, actor string, digest [32]byte, id string, in Input, now time.Time) (d.Record, error) {
	if s.Box == nil || len(s.RelayPublicKey) != ed25519.PublicKeySize || !receipt.ID(s.Scope.InstallationID) {
		return d.Record{}, d.ErrUnavailable
	}
	if !receipt.ID(actor) || !receipt.ID(id) || in.ExpectedGeneration < 1 || in.ExpectedGeneration > 1e9 {
		return d.Record{}, d.ErrInvalid
	}
	grant, err := receipt.Verify(s.RelayPublicKey, in.Receipt, now)
	if err != nil {
		return d.Record{}, d.ErrInvalid
	}
	if grant.Origin != s.Scope.Origin || grant.InstallationID != s.Scope.InstallationID || grant.InstallationPublicKey != s.InstallationPublicKey || grant.Namespace != s.Scope.Namespace || grant.BindingID != id || grant.Generation != in.ExpectedGeneration {
		return d.Record{}, d.ErrInvalid
	}
	raw, _ := json.Marshal(in.Receipt)
	hash := sha256.Sum256(raw)
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.Database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return d.Record{}, err
	}
	defer rollback(tx)
	var active int
	err = tx.QueryRow(ctx, `SELECT 1 FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_digest=$1 AND s.user_id=$2::uuid AND s.revoked_at IS NULL AND s.expires_at>$3 AND s.last_active_at>$3::timestamptz-($4::double precision*interval '1 second')AND u.blocked_at IS NULL FOR SHARE OF s,u`, digest[:], actor, now, int64(session.IdleLifetime.Seconds())).Scan(&active)
	if errors.Is(err, pgx.ErrNoRows) {
		return d.Record{}, d.ErrUnauthorized
	}
	if err != nil {
		return d.Record{}, err
	}
	var nonce, registration []byte
	var until *time.Time
	err = tx.QueryRow(ctx, `SELECT nonce_digest,enrollment_until,registration_hash FROM notification_devices WHERE id=$1::uuid AND account_id=$2::uuid FOR UPDATE`, id, actor).Scan(&nonce, &until, &registration)
	if errors.Is(err, pgx.ErrNoRows) {
		return d.Record{}, ErrNotFound
	}
	if err != nil {
		return d.Record{}, err
	}
	device, err := reader.New(tx).Binding(ctx, id, actor, s.Scope.Origin, s.Scope.InstallationID, s.Scope.Namespace, now)
	if errors.Is(err, reader.ErrUnavailable) {
		return d.Record{}, ErrNotFound
	}
	if err != nil {
		return d.Record{}, err
	}
	if device.SessionDigest != digest {
		return d.Record{}, ErrNotFound
	}
	if device.Transport != "mobile_relay" || device.Generation != in.ExpectedGeneration || !device.ExpiresAt.After(now) {
		return d.Record{}, d.ErrConflict
	}
	if device.State == "active" && subtle.ConstantTimeCompare(registration, hash[:]) == 1 {
		return device, tx.Commit(ctx)
	}
	received, _ := base64.RawURLEncoding.Strict().DecodeString(grant.Nonce)
	expected := sha256.Sum256(received)
	if device.State != "registering" || until == nil || !until.After(now) || subtle.ConstantTimeCompare(nonce, expected[:]) != 1 {
		return d.Record{}, d.ErrConflict
	}
	cipher, err := s.Box.Seal(raw, device.Scope())
	if err != nil {
		return d.Record{}, d.ErrUnavailable
	}
	expires := grant.ExpiresAt.UTC().Truncate(time.Microsecond)
	if device.ExpiresAt.Before(expires) {
		expires = device.ExpiresAt
	}
	fingerprint := sha256.Sum256([]byte("relay-grant/v1\x00" + grant.TenantID + "\x00" + grant.GrantID))
	_, err = tx.Exec(ctx, `UPDATE notification_devices SET state='active',secret_cipher=$2,fingerprint=$3,registration_hash=$4,nonce_digest=NULL,enrollment_until=NULL,expires_at=$5,updated_at=$6 WHERE id=$1::uuid`, id, cipher, fingerprint[:], hash[:], expires, now)
	if err != nil {
		var pgError *pgconn.PgError
		if errors.As(err, &pgError) && pgError.Code == "23505" {
			return d.Record{}, d.ErrConflict
		}
		return d.Record{}, err
	}
	device.State = "active"
	device.SecretCipher = cipher
	device.ExpiresAt = expires
	if err = tx.Commit(ctx); err != nil {
		return d.Record{}, err
	}
	return device, nil
}
func rollback(tx pgx.Tx) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = tx.Rollback(ctx)
}
