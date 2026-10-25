package enrolldevice

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
)

func (s Service) Challenge(ctx context.Context, in Challenge, source string, now time.Time) (Enrollment, error) {
	if s.Platforms != nil && !s.Platforms[in.Platform] {
		return Enrollment{}, ErrInvalid
	}
	key, err := base64.RawURLEncoding.Strict().DecodeString(in.PublicKey)
	if err != nil || len(key) != 32 || len(in.Target) < 16 || len(in.Target) > 4096 || (in.TargetKind != "fcm_fid" && in.TargetKind != "fcm_token") || in.Namespace != s.Namespace || (in.Platform != "android" && in.Platform != "ios") || s.Box == nil {
		return Enrollment{}, ErrInvalid
	}
	for _, c := range in.Target {
		if c < 33 || c > 126 {
			return Enrollment{}, ErrInvalid
		}
	}
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
	if !policy.Enabled || policy.Pending >= policy.MaxPending {
		return Enrollment{}, auth.ErrLimit
	}
	sourceHash := sha256.Sum256([]byte(source))
	allowed, err := auth.Budget(ctx, tx, "source", hex.EncodeToString(sourceHash[:]), 10, now)
	if err != nil {
		return Enrollment{}, err
	}
	if !allowed {
		return Enrollment{}, auth.ErrLimit
	}
	allowed, err = auth.Budget(ctx, tx, "global", "enroll", 1000, now)
	if err != nil {
		return Enrollment{}, err
	}
	if !allowed {
		return Enrollment{}, auth.ErrLimit
	}
	hash := sha256.Sum256([]byte(in.TargetKind + "\x00" + in.Target))
	existing, found, err := find(ctx, tx, hash, key, in, now)
	if err != nil {
		return Enrollment{}, err
	}
	if found {
		return existing, tx.Commit(ctx)
	}
	var count int
	if err = tx.QueryRow(ctx, `SELECT count(*) FROM relay_devices`).Scan(&count); err != nil {
		return Enrollment{}, err
	}
	if count >= 10000 {
		return Enrollment{}, auth.ErrLimit
	}
	id := uuid.NewString()
	nonce := make([]byte, 32)
	if _, err = rand.Read(nonce); err != nil {
		return Enrollment{}, err
	}
	nonceHash := sha256.Sum256(nonce)
	cipher, err := s.Box.Seal([]byte(in.Target), DeviceScope(id, s.Namespace, in.TargetKind, in.Platform, key))
	if err != nil {
		return Enrollment{}, err
	}
	until := now.Add(5 * time.Minute)
	_, err = tx.Exec(ctx, `INSERT INTO relay_devices(id,public_key,namespace,platform,token_cipher,token_hash,challenge_hash,challenge_until,state,expires_at,created_at,updated_at,target_kind)
 VALUES($1::uuid,$2,$3,$4,$5,$6,$7,$8,'pending',$9,$10,$10,$11)`, id, key, s.Namespace, in.Platform, cipher, hash[:], nonceHash[:], until, now.Add(180*24*time.Hour), now, in.TargetKind)
	if err != nil {
		return Enrollment{}, err
	}
	raw, _ := json.Marshal(Proof{id, base64.RawURLEncoding.EncodeToString(nonce)})
	job := uuid.NewString()
	payload, err := s.Box.Seal(raw, JobScope(job, id, "", "challenge", s.Namespace, id))
	if err != nil {
		return Enrollment{}, err
	}
	_, err = tx.Exec(ctx, `INSERT INTO relay_jobs(id,device_id,job_ref,kind,payload_cipher,request_hash,expires_at,due_at,epoch,created_at)VALUES($1::uuid,$2::uuid,$2::uuid,'challenge',$3,$4,$5,$6,$7,$6)`, job, id, payload, nonceHash[:], until, now, policy.Epoch)
	if err != nil {
		return Enrollment{}, err
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_policy SET pending=pending+1 WHERE singleton`); err != nil {
		return Enrollment{}, err
	}
	return Enrollment{1, id, "pending", until}, tx.Commit(ctx)
}
func rollback(tx pgx.Tx) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = tx.Rollback(ctx)
}
