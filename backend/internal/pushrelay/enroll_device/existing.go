package enrolldevice

import (
	"bytes"
	"context"
	"crypto/sha256"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
)

func find(ctx context.Context, tx pgx.Tx, hash [sha256.Size]byte, key []byte, in Challenge, now time.Time) (Enrollment, bool, error) {
	out := Enrollment{Version: 1}
	var stored []byte
	var platform string
	var challenge *time.Time
	err := tx.QueryRow(ctx, `SELECT id::text,state,expires_at,public_key,platform,challenge_until FROM relay_devices WHERE token_hash=$1 AND namespace=$2 AND state IN('pending','active') FOR UPDATE`, hash[:], in.Namespace).Scan(&out.DeviceID, &out.State, &out.ExpiresAt, &stored, &platform, &challenge)
	if errors.Is(err, pgx.ErrNoRows) {
		return out, false, nil
	}
	if err != nil {
		return out, false, err
	}
	if !out.ExpiresAt.After(now) || out.State == "pending" && (challenge == nil || !challenge.After(now)) {
		_, err = tx.Exec(ctx, `UPDATE relay_devices SET state='revoked',updated_at=$2 WHERE id=$1::uuid`, out.DeviceID, now)
		return out, false, err
	}
	if !bytes.Equal(stored, key) || platform != in.Platform || out.State == "revoked" || out.State == "invalid" || !out.ExpiresAt.After(now) {
		return out, true, ErrConflict
	}
	if out.State == "pending" {
		if challenge == nil || !challenge.After(now) {
			return out, true, ErrConflict
		}
		out.ExpiresAt = *challenge
	}
	return out, true, nil
}
