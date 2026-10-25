package dispatchjob

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
)

func (s Store) Next(ctx context.Context, now time.Time) (Work, bool, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.Database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return Work{}, false, err
	}
	defer rollback(tx)
	policy, err := auth.Lock(ctx, tx)
	if err != nil {
		return Work{}, false, err
	}
	if !policy.Enabled {
		return Work{}, false, nil
	}
	j := Job{LeaseOwner: uuid.NewString()}
	err = tx.QueryRow(ctx, `WITH candidate AS(SELECT id FROM relay_jobs WHERE device_id IN(SELECT id FROM relay_devices WHERE namespace=$4) AND state IN('pending','claimed','retry') AND due_at<=$1 AND(lease_until IS NULL OR lease_until<$1)AND epoch=$2 ORDER BY due_at,id LIMIT 1 FOR UPDATE SKIP LOCKED)
 UPDATE relay_jobs j SET state='claimed',lease_owner=$3::uuid,lease_until=$1::timestamptz+interval '30 seconds' FROM candidate WHERE j.id=candidate.id
 RETURNING j.id::text,j.device_id::text,COALESCE(j.grant_id::text,''),j.kind,j.epoch,j.attempts,j.payload_cipher,j.expires_at,j.started_at,j.job_ref::text`, now, policy.Epoch, j.LeaseOwner, s.Namespace).Scan(&j.ID, &j.DeviceID, &j.GrantID, &j.Kind, &j.Epoch, &j.Attempts, &j.Cipher, &j.ExpiresAt, &j.StartedAt, &j.Reference)
	if errors.Is(err, pgx.ErrNoRows) {
		return Work{}, false, nil
	}
	if err != nil {
		return Work{}, false, err
	}
	stop := func(state string) (Work, bool, error) {
		if err := terminal(ctx, tx, j, state, s.Namespace); err != nil {
			return Work{}, false, err
		}
		return Work{}, false, tx.Commit(ctx)
	}
	if j.StartedAt != nil {
		return stop("delivery_unknown")
	}
	if !j.ExpiresAt.After(now) {
		return stop("expired")
	}
	if j.Attempts >= 6 {
		return stop("permanent_failure")
	}
	message, allowed, err := s.read(ctx, tx, j, now)
	if err != nil {
		return Work{}, false, err
	}
	if !allowed {
		return stop("revoked")
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_jobs SET started_at=$2,attempts=attempts+1 WHERE id=$1::uuid`, j.ID, now); err != nil {
		return Work{}, false, err
	}
	j.Attempts++
	j.StartedAt = &now
	if err = tx.Commit(ctx); err != nil {
		return Work{}, false, err
	}
	return Work{j, message}, true, nil
}
