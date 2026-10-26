package plandelivery

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
)

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Store struct{ database Database }

func New(database Database) Store { return Store{database} }

type Intent struct {
	ID, InstallationID, MessageID, ConversationID, Kind, AuthorID, Cursor, LeaseOwner string
	Mentions                                                                          []string
	CreatedAt, ExpiresAt, DueAt                                                       time.Time
	Epoch                                                                             int64
}

func (s Store) Claim(ctx context.Context, now time.Time) (Intent, bool, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return Intent{}, false, err
	}
	defer rollback(tx)
	policy, err := control.Lock(ctx, tx)
	if err != nil {
		return Intent{}, false, err
	}
	if !policy.Enabled {
		return Intent{}, false, nil
	}
	token := uuid.NewString()
	var in Intent
	err = tx.QueryRow(ctx, `WITH candidate AS(SELECT id FROM notification_outbox
 WHERE state IN('pending','planning') AND due_at<=$1 AND (lease_until IS NULL OR lease_until<$1) AND epoch=$2
 ORDER BY due_at,id LIMIT 1 FOR UPDATE SKIP LOCKED)
 UPDATE notification_outbox o SET state='planning',lease_owner=$3::uuid,lease_until=$1+interval '30 seconds'
 FROM candidate WHERE o.id=candidate.id
 RETURNING o.id::text,o.installation_id::text,o.message_id::text,o.conversation_id::text,o.kind,o.author_id::text,o.mention_user_ids,o.created_at,o.expires_at,o.due_at,o.epoch,o.cursor_account::text,o.lease_owner::text`, now, policy.Epoch, token).Scan(&in.ID, &in.InstallationID, &in.MessageID, &in.ConversationID, &in.Kind, &in.AuthorID, &in.Mentions, &in.CreatedAt, &in.ExpiresAt, &in.DueAt, &in.Epoch, &in.Cursor, &in.LeaseOwner)
	if errors.Is(err, pgx.ErrNoRows) {
		return Intent{}, false, nil
	}
	if err != nil {
		return Intent{}, false, err
	}
	if err = tx.Commit(ctx); err != nil {
		return Intent{}, false, err
	}
	return in, true, nil
}
func rollback(tx pgx.Tx) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = tx.Rollback(ctx)
}
