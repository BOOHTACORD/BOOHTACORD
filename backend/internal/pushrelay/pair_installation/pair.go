package pairinstallation

import (
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/json"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
	signature "voice-platform/backend/internal/pushrelay/request_signature"
)

func (s Service) Pair(ctx context.Context, request signature.Request, in Input, now time.Time) (receipt.Receipt, error) {
	if len(s.SigningKey) != ed25519.PrivateKeySize || in.validate(s.Namespace, now) != nil || !bodyMatches(request.Body, in) || request.Method != "POST" || request.Path != "/v1/grants" {
		return receipt.Receipt{}, ErrInvalid
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.Database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return receipt.Receipt{}, err
	}
	defer rollback(tx)
	policy, err := auth.Lock(ctx, tx)
	if err != nil {
		return receipt.Receipt{}, err
	}
	if !policy.Enabled {
		return receipt.Receipt{}, auth.ErrLimit
	}
	if err = auth.Verify(ctx, tx, request, "device", false, now); err != nil {
		return receipt.Receipt{}, err
	}
	var namespace string
	var expires time.Time
	if err = tx.QueryRow(ctx, `SELECT namespace,expires_at FROM relay_devices WHERE id=$1::uuid`, request.Subject).Scan(&namespace, &expires); err != nil {
		return receipt.Receipt{}, err
	}
	if namespace != s.Namespace {
		return receipt.Receipt{}, auth.ErrDenied
	}
	tenant, err := pin(ctx, tx, in, now)
	if err != nil {
		return receipt.Receipt{}, err
	}
	old, found, err := existing(ctx, tx, tenant, request.Subject, in, now)
	if err != nil {
		return receipt.Receipt{}, err
	}
	if found {
		return old, tx.Commit(ctx)
	}
	var deviceCount, tenantCount, total int
	if err = tx.QueryRow(ctx, `SELECT count(*)FILTER(WHERE device_id=$1::uuid AND state='active' AND expires_at>$3),count(*)FILTER(WHERE tenant_id=$2::uuid AND state='active' AND expires_at>$3),count(*) FROM relay_grants`, request.Subject, tenant, now).Scan(&deviceCount, &tenantCount, &total); err != nil {
		return receipt.Receipt{}, err
	}
	if deviceCount >= 20 || tenantCount >= 1000 || total >= 10000 {
		return receipt.Receipt{}, auth.ErrLimit
	}
	// A new generation may replace only the same physical app key's old route.
	rows, err := tx.Query(ctx, `SELECT d.public_key FROM relay_grants g JOIN relay_devices d ON d.id=g.device_id WHERE g.tenant_id=$1::uuid AND g.binding_id=$2::uuid AND(g.generation>=$3 OR d.public_key<>(SELECT public_key FROM relay_devices WHERE id=$4::uuid)) LIMIT 1`, tenant, in.BindingID, in.Generation, request.Subject)
	if err != nil {
		return receipt.Receipt{}, err
	}
	conflict := rows.Next()
	err = rows.Err()
	rows.Close()
	if err != nil {
		return receipt.Receipt{}, err
	}
	if conflict {
		return receipt.Receipt{}, ErrConflict
	}
	if limit := now.Add(90 * 24 * time.Hour); expires.After(limit) {
		expires = limit
	}
	grant := receipt.Grant{Version: 1, GrantID: uuid.NewString(), TenantID: tenant, Origin: in.Origin, InstallationID: in.InstallationID, InstallationPublicKey: in.InstallationPublicKey, BindingID: in.BindingID, Generation: in.Generation, Namespace: in.Namespace, Nonce: in.Nonce, ExpiresAt: expires}
	signed, err := receipt.Sign(s.SigningKey, grant, now)
	if err != nil {
		return receipt.Receipt{}, err
	}
	raw, _ := json.Marshal(signed)
	hash := sha256.Sum256(key(in.Nonce))
	if _, err = tx.Exec(ctx, `UPDATE relay_grants SET state='revoked' WHERE tenant_id=$1::uuid AND binding_id=$2::uuid AND generation<$3 AND state='active'`, tenant, in.BindingID, in.Generation); err != nil {
		return receipt.Receipt{}, err
	}
	_, err = tx.Exec(ctx, `INSERT INTO relay_grants(id,tenant_id,device_id,binding_id,generation,nonce_hash,receipt,expires_at,created_at)VALUES($1::uuid,$2::uuid,$3::uuid,$4::uuid,$5,$6,$7,$8,$9)`, grant.GrantID, tenant, request.Subject, in.BindingID, in.Generation, hash[:], raw, expires, now)
	if err != nil {
		return receipt.Receipt{}, err
	}
	return signed, tx.Commit(ctx)
}
