package acceptnotification

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
	enroll "voice-platform/backend/internal/pushrelay/enroll_device"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
	signature "voice-platform/backend/internal/pushrelay/request_signature"
)

func (s Service) Accept(ctx context.Context, request signature.Request, in Input, now time.Time) (Status, error) {
	if !receipt.ID(in.GrantID) || !receipt.ID(in.Payload.NotificationRef) || !receipt.ID(in.Payload.BindingRef) || !matches(request.Body, in) || in.Payload.Validate(now) != nil || in.Payload.ExpiresAt.After(now.Add(time.Hour)) || s.Box == nil || request.Method != "POST" || request.Path != "/v1/notifications" {
		return Status{}, ErrInvalid
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.Database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return Status{}, err
	}
	defer rollback(tx)
	policy, err := auth.Lock(ctx, tx)
	if err != nil {
		return Status{}, err
	}
	if err = auth.Verify(ctx, tx, request, "tenant", false, now); err != nil {
		return Status{}, err
	}
	route, err := destination(ctx, tx, in.GrantID, request.Subject, s.Namespace, now)
	if err != nil {
		return Status{}, err
	}
	if s.Platforms != nil && !s.Platforms[route.Platform] {
		return Status{}, ErrRouteUnavailable
	}
	if route.Binding != in.Payload.BindingRef || route.Generation != in.Payload.Generation {
		return Status{}, auth.ErrDenied
	}
	raw, _ := json.Marshal(in)
	hash := sha256.Sum256(raw)
	old, found, err := existing(ctx, tx, in, hash[:])
	if err != nil {
		return Status{}, err
	}
	if found {
		return old, tx.Commit(ctx)
	}
	if !policy.Enabled || policy.Pending >= policy.MaxPending {
		return Status{}, auth.ErrLimit
	}
	for _, quota := range []struct {
		scope, id string
		limit     int
	}{{"tenant", request.Subject, 1000}, {"device", route.Device, 60}, {"global", "send", 1000}} {
		allowed, err := auth.Budget(ctx, tx, quota.scope, quota.id, quota.limit, now)
		if err != nil {
			return Status{}, err
		}
		if !allowed {
			return Status{}, auth.ErrLimit
		}
	}
	var retained int
	if err = tx.QueryRow(ctx, `SELECT count(*)FROM relay_jobs`).Scan(&retained); err != nil {
		return Status{}, err
	}
	if retained >= 100000 {
		return Status{}, auth.ErrLimit
	}
	job := uuid.NewString()
	payloadValue := in.Payload
	if route.ExpiresAt.Before(payloadValue.ExpiresAt) {
		payloadValue.ExpiresAt = route.ExpiresAt
	}
	payloadValue.ExpiresAt = payloadValue.ExpiresAt.Truncate(time.Microsecond)
	payload, _ := json.Marshal(payloadValue)
	cipher, err := s.Box.Seal(payload, enroll.JobScope(job, route.Device, in.GrantID, "notification", s.Namespace, in.Payload.NotificationRef))
	if err != nil {
		return Status{}, err
	}
	_, err = tx.Exec(ctx, `INSERT INTO relay_jobs(id,tenant_id,grant_id,device_id,job_ref,kind,payload_cipher,request_hash,expires_at,due_at,epoch,created_at)
 VALUES($1::uuid,$2::uuid,$3::uuid,$4::uuid,$5::uuid,'notification',$6,$7,$8,$9,$10,$9)`, job, request.Subject, in.GrantID, route.Device, in.Payload.NotificationRef, cipher, hash[:], payloadValue.ExpiresAt, now, policy.Epoch)
	if err != nil {
		return Status{}, err
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_policy SET pending=pending+1 WHERE singleton`); err != nil {
		return Status{}, err
	}
	if _, err = tx.Exec(ctx, `INSERT INTO relay_counters(outcome,namespace,value)VALUES('accepted_by_relay',$1,1)ON CONFLICT(outcome,namespace)DO UPDATE SET value=relay_counters.value+1`, s.Namespace); err != nil {
		return Status{}, err
	}
	return Status{1, in.Payload.NotificationRef, "accepted_by_relay", payloadValue.ExpiresAt}, tx.Commit(ctx)
}
