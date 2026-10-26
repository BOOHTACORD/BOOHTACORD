package enrolldevice

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"github.com/jackc/pgx/v5"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
	signature "voice-platform/backend/internal/pushrelay/request_signature"
)

func (s Service) Verify(ctx context.Context, request signature.Request, in Proof, now time.Time) (Enrollment, error) {
	raw, err := base64.RawURLEncoding.Strict().DecodeString(in.Nonce)
	if err != nil || len(raw) != 32 || in.ChallengeID != request.Subject {
		return Enrollment{}, ErrInvalid
	}
	var signed Proof
	if json.Unmarshal(request.Body, &signed) != nil || signed != in {
		return Enrollment{}, ErrInvalid
	}
	// API passes the original signed bytes. Decode/re-encode is deliberately not
	// used for verification: whitespace and field changes remain signature-bound.
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.Database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return Enrollment{}, err
	}
	defer rollback(tx)
	policy, err := auth.Lock(ctx, tx)
	if err != nil {
		return Enrollment{}, err
	}
	if !policy.Enabled {
		return Enrollment{}, auth.ErrLimit
	}
	if err = auth.Verify(ctx, tx, request, "device", true, now); err != nil {
		return Enrollment{}, err
	}
	var expected []byte
	var until *time.Time
	out := Enrollment{Version: 1, DeviceID: in.ChallengeID}
	if err = tx.QueryRow(ctx, `SELECT challenge_hash,challenge_until,state,expires_at FROM relay_devices WHERE id=$1::uuid FOR UPDATE`, in.ChallengeID).Scan(&expected, &until, &out.State, &out.ExpiresAt); err != nil {
		return Enrollment{}, err
	}
	hash := sha256.Sum256(raw)
	if subtle.ConstantTimeCompare(hash[:], expected) != 1 {
		return Enrollment{}, auth.ErrDenied
	}
	if out.State == "active" {
		return out, tx.Commit(ctx)
	}
	if until == nil || !until.After(now) || out.State != "pending" {
		return Enrollment{}, auth.ErrDenied
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_devices SET state='active',updated_at=$2 WHERE id=$1::uuid`, in.ChallengeID, now); err != nil {
		return Enrollment{}, err
	}
	out.State = "active"
	return out, tx.Commit(ctx)
}
