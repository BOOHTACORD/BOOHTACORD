package pairinstallation

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
)

var ErrConflict = errors.New("relay installation key or generation conflict")
var ErrInvalid = errors.New("invalid relay pairing")

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Service struct {
	Database   Database
	SigningKey ed25519.PrivateKey
	Namespace  string
}
type Input struct {
	Origin                string `json:"origin"`
	InstallationID        string `json:"installation_id"`
	InstallationPublicKey string `json:"installation_public_key"`
	BindingID             string `json:"binding_id"`
	Generation            int64  `json:"generation"`
	Namespace             string `json:"namespace"`
	Nonce                 string `json:"nonce"`
}

func (in Input) validate(namespace string, now time.Time) error {
	prototype := receipt.Grant{Version: 1, GrantID: in.BindingID, TenantID: in.InstallationID, Origin: in.Origin, InstallationID: in.InstallationID, InstallationPublicKey: in.InstallationPublicKey, BindingID: in.BindingID, Generation: in.Generation, Namespace: in.Namespace, Nonce: in.Nonce, ExpiresAt: now.Add(time.Hour)}
	if in.Namespace != namespace || prototype.Validate(now) != nil {
		return ErrInvalid
	}
	return nil
}
func key(raw string) []byte { b, _ := base64.RawURLEncoding.Strict().DecodeString(raw); return b }
func bodyMatches(raw []byte, in Input) bool {
	var decoded Input
	return json.Unmarshal(raw, &decoded) == nil && decoded == in
}
func existing(ctx context.Context, tx pgx.Tx, tenant, device string, in Input, now time.Time) (receipt.Receipt, bool, error) {
	var raw, nonce []byte
	var owner, state string
	var expires time.Time
	err := tx.QueryRow(ctx, `SELECT device_id::text,state,expires_at,nonce_hash,receipt FROM relay_grants WHERE tenant_id=$1::uuid AND binding_id=$2::uuid AND generation=$3 FOR UPDATE`, tenant, in.BindingID, in.Generation).Scan(&owner, &state, &expires, &nonce, &raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return receipt.Receipt{}, false, nil
	}
	if err != nil {
		return receipt.Receipt{}, false, err
	}
	hash := sha256.Sum256(key(in.Nonce))
	if owner != device || state != "active" || !expires.After(now) || !bytes.Equal(hash[:], nonce) {
		return receipt.Receipt{}, true, ErrConflict
	}
	var out receipt.Receipt
	if json.Unmarshal(raw, &out) != nil {
		return out, true, ErrInvalid
	}
	return out, true, nil
}
func rollback(tx pgx.Tx) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = tx.Rollback(ctx)
}
