package resolvereference

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"time"
	observe "voice-platform/backend/internal/notifications/observe_delivery"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
)

var ErrNotFound = errors.New("notification unavailable")

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Store struct {
	database Database
	scope    reader.Scope
}

func New(database Database, scope reader.Scope) Store { return Store{database, scope} }

type Target struct {
	Version        int    `json:"version"`
	Kind           string `json:"kind"`
	ConversationID string `json:"conversation_id"`
	MessageID      string `json:"message_id"`
}
type Request struct {
	Ref        string `json:"ref"`
	Generation int64  `json:"generation"`
}

func Valid(in Request) bool {
	id, err := uuid.Parse(in.Ref)
	return err == nil && id != uuid.Nil && id.String() == in.Ref && in.Generation > 0 && in.Generation <= 1000000000
}
func (s Store) Resolve(ctx context.Context, actor string, in Request, now time.Time) (Target, error) {
	ctx, endSpan := observe.Span(ctx, "notification.resolve")
	defer endSpan()
	if !Valid(in) {
		return Target{}, ErrNotFound
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return Target{}, err
	}
	defer rollback(tx)
	var binding, kind, messageID, conversation string
	var expires time.Time
	err = tx.QueryRow(ctx, `SELECT binding_id::text,kind,message_id::text,conversation_id::text,expires_at FROM notification_deliveries
 WHERE id=$1::uuid AND account_id=$2::uuid AND binding_generation=$3`, in.Ref, actor, in.Generation).Scan(&binding, &kind, &messageID, &conversation, &expires)
	if errors.Is(err, pgx.ErrNoRows) || (!expires.IsZero() && !expires.After(now)) {
		return Target{}, ErrNotFound
	}
	if err != nil {
		return Target{}, err
	}
	source := reader.New(tx)
	d, err := source.Binding(ctx, binding, actor, s.scope.Origin, s.scope.InstallationID, s.scope.Namespace, now)
	if errors.Is(err, reader.ErrUnavailable) {
		return Target{}, ErrNotFound
	}
	if err != nil {
		return Target{}, err
	}
	if d.State != "active" || d.Generation != in.Generation || !d.ExpiresAt.After(now) {
		return Target{}, ErrNotFound
	}
	m, err := source.Message(ctx, kind, messageID)
	if errors.Is(err, reader.ErrUnavailable) {
		return Target{}, ErrNotFound
	}
	if err != nil {
		return Target{}, err
	}
	if m.Deleted || m.Archived || m.AuthorBlocked || m.ConversationID != conversation {
		return Target{}, ErrNotFound
	}
	allowed, err := source.Allowed(ctx, actor, kind, conversation)
	if err != nil {
		return Target{}, err
	}
	if !allowed {
		return Target{}, ErrNotFound
	}
	changed, err := tx.Exec(ctx, `UPDATE notification_deliveries SET opened_at=$2 WHERE id=$1::uuid AND opened_at IS NULL`, in.Ref, now)
	if err != nil {
		return Target{}, err
	}
	if err = observe.Record(ctx, tx, "opened", "none", d.Transport, changed.RowsAffected()); err != nil {
		return Target{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return Target{}, err
	}
	return Target{1, kind, conversation, messageID}, nil
}
func rollback(tx pgx.Tx) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = tx.Rollback(ctx)
}
