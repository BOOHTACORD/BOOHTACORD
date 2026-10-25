package dispatchdelivery

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
	observe "voice-platform/backend/internal/notifications/observe_delivery"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	"voice-platform/backend/internal/notifications/secretbox"
)

// Begin commits the attempt marker before returning any provider secret.
// A recovered marker is ambiguous, so a crash can never cause a blind resend.
func (s Store) Begin(ctx context.Context, claim Job, scope reader.Scope, box *secretbox.Box, now time.Time) (Message, bool, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return Message{}, false, err
	}
	defer rollback(tx)
	policy, err := control.Lock(ctx, tx)
	if err != nil {
		return Message{}, false, err
	}
	job, presented, err := owned(ctx, tx, claim)
	if err != nil {
		return Message{}, false, err
	}
	if !policy.Enabled || policy.Epoch != job.Epoch || !job.LeaseUntil.After(now) {
		return Message{}, false, ErrLostLease
	}
	stop := func(state, reason, transport string) (Message, bool, error) {
		if err := settle(ctx, tx, job, state, reason, transport, now); err != nil {
			return Message{}, false, err
		}
		return Message{}, false, tx.Commit(ctx)
	}
	if job.AttemptStartedAt != nil {
		return stop("delivery_unknown", "lease_expired", "none")
	}
	if !job.ExpiresAt.After(now) {
		return stop("expired", "expired", "none")
	}
	if presented {
		return stop("suppressed", "attention", "none")
	}
	if job.Attempts >= 6 {
		return stop("permanent_failure", "provider_error", "none")
	}
	admitted, reason, err := check(ctx, tx, job, scope, now)
	if err != nil {
		return Message{}, false, err
	}
	if reason != "" {
		return stop("suppressed", reason, admitted.device.Transport)
	}
	device := admitted.device
	// Rotation is allowed only on the same immutable account/session binding.
	job.BindingGeneration = device.Generation
	if box == nil {
		return stop("permanent_failure", "configuration_error", device.Transport)
	}
	secret, err := box.Open(device.SecretCipher, device.Scope())
	if err != nil {
		return stop("permanent_failure", "configuration_error", device.Transport)
	}
	postponed, err := deferAttention(ctx, tx, job, now)
	if err != nil {
		return Message{}, false, err
	}
	if postponed {
		return Message{}, false, tx.Commit(ctx)
	}
	available, err := reserveGroup(ctx, tx, job, policy.SoundSeconds, now)
	if errors.Is(err, errGroupBusy) {
		return Message{}, false, tx.Commit(ctx)
	}
	if err != nil {
		return Message{}, false, err
	}
	if !available {
		return stop("suppressed", "grouped", device.Transport)
	}
	permitted, err := quota(ctx, tx, admitted.author, job.AccountID, scope.InstallationID, now)
	if err != nil {
		return Message{}, false, err
	}
	if !permitted {
		return stop("suppressed", "quota", device.Transport)
	}
	_, err = tx.Exec(ctx, `UPDATE notification_deliveries SET binding_generation=$3,attempts=attempts+1,attempt_started_at=$4,lease_until=$4::timestamptz+interval '30 seconds' WHERE id=$1::uuid AND lease_owner=$2::uuid`, job.ID, job.LeaseOwner, job.BindingGeneration, now)
	if err != nil {
		return Message{}, false, err
	}
	if err = observe.Record(ctx, tx, "attempt", "none", device.Transport, 1); err != nil {
		return Message{}, false, err
	}
	if err = tx.Commit(ctx); err != nil {
		return Message{}, false, err
	}
	return Message{Payload: job.Payload(), Secret: secret, Transport: device.Transport, OccurredAt: job.CreatedAt}, true, nil
}
