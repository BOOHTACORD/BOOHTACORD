package publishhint

import (
	"context"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"time"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	hub "voice-platform/backend/internal/realtime/event_hub"
)

type Publisher struct {
	Database *pgxpool.Pool
	Events   *hub.Hub
}
type hint struct {
	ID, Account, Binding, Kind, Conversation, Message string
	Generation                                        int64
}

func (p Publisher) Run(ctx context.Context, now time.Time) error {
	if p.Events == nil {
		return nil
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	rows, err := p.Database.Query(ctx, `UPDATE notification_deliveries j SET hint_emitted_at=$1 WHERE id IN(
 SELECT id FROM notification_deliveries WHERE hint_emitted_at IS NULL AND state IN('pending','retry') AND expires_at>$1 ORDER BY due_at,id LIMIT 32)
 RETURNING id::text,account_id::text,binding_id::text,binding_generation,kind,conversation_id::text,message_id::text`, now)
	if err != nil {
		return err
	}
	batch := make([]hint, 0, 32)
	for rows.Next() {
		var h hint
		if err = rows.Scan(&h.ID, &h.Account, &h.Binding, &h.Generation, &h.Kind, &h.Conversation, &h.Message); err != nil {
			rows.Close()
			return err
		}
		batch = append(batch, h)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	for _, h := range batch {
		allowed, err := reader.New(p.Database).Allowed(ctx, h.Account, h.Kind, h.Conversation)
		if err != nil {
			return err
		}
		if !allowed {
			continue
		}
		p.Events.PublishToAccountsTransient([]string{h.Account}, hub.Event{EventID: uuid.NewString(), Kind: "notification.queued", OccurredAt: now, Payload: map[string]any{"version": 1, "ref": h.ID, "binding_ref": h.Binding, "generation": h.Generation, "kind": h.Kind, "conversation_id": h.Conversation, "message_id": h.Message}})
	}
	return nil
}
