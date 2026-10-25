package dispatchdelivery

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
)

var errGroupBusy = errors.New("notification group reserved")

func reserveGroup(ctx context.Context, tx pgx.Tx, j Job, sound int, now time.Time) (bool, error) {
	var last, reservation *time.Time
	var owner *string
	err := tx.QueryRow(ctx, `SELECT last_signaled_at,reservation_job::text,reservation_until FROM notification_groups
 WHERE binding_id=$1::uuid AND kind=$2 AND conversation_id=$3::uuid FOR UPDATE`, j.BindingID, j.Kind, j.ConversationID).Scan(&last, &owner, &reservation)
	if err != nil {
		return false, err
	}
	if last != nil && now.Before(last.Add(time.Duration(sound)*time.Second)) {
		return false, nil
	}
	// Another in-flight send reserves this group. Retry after its short lease,
	// rather than claiming that a not-yet-accepted request notified the user.
	if owner != nil && *owner != j.ID && reservation != nil && reservation.After(now) {
		_, err = tx.Exec(ctx, `UPDATE notification_deliveries SET state='retry',due_at=$2,lease_owner=NULL,lease_until=NULL WHERE id=$1::uuid`, j.ID, *reservation)
		if err != nil {
			return false, err
		}
		return false, errGroupBusy
	}
	_, err = tx.Exec(ctx, `UPDATE notification_groups SET reservation_job=$4::uuid,reservation_until=$5::timestamptz+interval '30 seconds',updated_at=$5
 WHERE binding_id=$1::uuid AND kind=$2 AND conversation_id=$3::uuid`, j.BindingID, j.Kind, j.ConversationID, j.ID, now)
	return true, err
}
func deferAttention(ctx context.Context, tx pgx.Tx, j Job, now time.Time) (bool, error) {
	limit := j.CreatedAt.Add(30 * time.Second)
	if !limit.After(now) {
		return false, nil
	}
	kind := "CHANNEL"
	if j.Kind == "DM" {
		kind = "DIRECT_MESSAGE"
	}
	var until *time.Time
	err := tx.QueryRow(ctx, `SELECT max(a.expires_at) FROM notification_attention a JOIN sessions s ON s.token_digest=a.session_digest
 WHERE a.account_id=$1::uuid AND a.kind=$2 AND a.conversation_id=$3::uuid AND a.expires_at>$4 AND s.revoked_at IS NULL AND s.expires_at>$4`, j.AccountID, kind, j.ConversationID, now).Scan(&until)
	if err != nil || until == nil {
		return false, err
	}
	if until.After(limit) {
		until = &limit
	}
	_, err = tx.Exec(ctx, `UPDATE notification_deliveries SET state='retry',due_at=$2,lease_owner=NULL,lease_until=NULL WHERE id=$1::uuid`, j.ID, *until)
	return true, err
}
