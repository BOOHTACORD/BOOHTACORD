package attention

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"time"
	"voice-platform/backend/internal/identity/session"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
)

var ErrInvalid = errors.New("invalid notification attention")
var ErrUnavailable = errors.New("notification attention unavailable")

type Input struct {
	ViewID         string `json:"view_id"`
	Kind           string `json:"kind"`
	ConversationID string `json:"conversation_id"`
	Visible        bool   `json:"visible"`
}
type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Store struct{ database Database }

func New(database Database) Store { return Store{database} }
func validID(raw string) bool {
	id, err := uuid.Parse(raw)
	return err == nil && id != uuid.Nil && id.String() == raw
}
func (s Store) Update(ctx context.Context, actor string, digest [32]byte, in Input, now time.Time) error {
	if !validID(in.ViewID) || !validID(in.ConversationID) || (in.Kind != "CHANNEL" && in.Kind != "DIRECT_MESSAGE") {
		return ErrInvalid
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := s.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer rollback(tx)
	var active int
	err = tx.QueryRow(ctx, `SELECT 1 FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_digest=$1 AND s.user_id=$2::uuid AND s.revoked_at IS NULL
 AND s.expires_at>$3 AND s.last_active_at>$3-($4::double precision*interval '1 second') AND u.blocked_at IS NULL FOR UPDATE OF s`, digest[:], actor, now, int64(session.IdleLifetime.Seconds())).Scan(&active)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrUnavailable
	}
	if err != nil {
		return err
	}
	if !in.Visible {
		_, err = tx.Exec(ctx, `DELETE FROM notification_attention WHERE account_id=$1::uuid AND session_digest=$2 AND view_id=$3::uuid`, actor, digest[:], in.ViewID)
		if err != nil {
			return err
		}
		return tx.Commit(ctx)
	}
	kind := "TEXT"
	if in.Kind == "DIRECT_MESSAGE" {
		kind = "DM"
	}
	allowed, err := reader.New(tx).Allowed(ctx, actor, kind, in.ConversationID)
	if err != nil {
		return err
	}
	if !allowed {
		return ErrUnavailable
	}
	_, err = tx.Exec(ctx, `DELETE FROM notification_attention WHERE (account_id,session_digest,view_id)IN(SELECT account_id,session_digest,view_id FROM notification_attention WHERE expires_at<=$1 LIMIT 16)`, now)
	if err != nil {
		return err
	}
	changed, err := tx.Exec(ctx, `INSERT INTO notification_attention(account_id,session_digest,view_id,kind,conversation_id,expires_at)
 SELECT $1::uuid,$2,$3::uuid,$4,$5::uuid,$6::timestamptz+interval '30 seconds'
 WHERE (SELECT count(*)FROM notification_attention WHERE account_id=$1::uuid AND session_digest=$2)<10
 OR EXISTS(SELECT 1 FROM notification_attention WHERE account_id=$1::uuid AND session_digest=$2 AND view_id=$3::uuid)
 ON CONFLICT(account_id,session_digest,view_id)DO UPDATE SET kind=EXCLUDED.kind,conversation_id=EXCLUDED.conversation_id,expires_at=EXCLUDED.expires_at`, actor, digest[:], in.ViewID, in.Kind, in.ConversationID, now)
	if err != nil {
		return err
	}
	if changed.RowsAffected() != 1 {
		return ErrUnavailable
	}
	return tx.Commit(ctx)
}
func rollback(tx pgx.Tx) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = tx.Rollback(ctx)
}
