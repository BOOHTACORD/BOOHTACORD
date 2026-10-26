package plandelivery

import (
	"context"
	"github.com/jackc/pgx/v5"
	"time"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	d "voice-platform/backend/internal/notifications/register_device"
)

func insertJob(ctx context.Context, tx pgx.Tx, in Intent, m reader.Message, account string, node d.Record, now time.Time) (int, error) {
	var group string
	err := tx.QueryRow(ctx, `INSERT INTO notification_groups(binding_id,kind,conversation_id,generation,ref_until,updated_at)
 VALUES($1::uuid,$2,$3::uuid,$4,$5,$6)
 ON CONFLICT(binding_id,kind,conversation_id)DO UPDATE SET generation=$4,
 group_ref=CASE WHEN notification_groups.ref_until<=$6 OR notification_groups.generation<>$4 THEN gen_random_uuid() ELSE notification_groups.group_ref END,
 ref_until=CASE WHEN notification_groups.ref_until<=$6 OR notification_groups.generation<>$4 THEN $5 ELSE notification_groups.ref_until END,updated_at=$6
 RETURNING group_ref::text`, node.ID, in.Kind, in.ConversationID, node.Generation, in.ExpiresAt, now).Scan(&group)
	if err != nil {
		return 0, err
	}
	template := "activity"
	if in.Kind == "DM" {
		template = "direct_message"
	} else if reader.VerifiedMention(in.Mentions, m.Mentions, account) {
		template = "mention"
	}
	result, err := tx.Exec(ctx, `INSERT INTO notification_deliveries(outbox_id,binding_id,binding_generation,account_id,kind,conversation_id,message_id,template,group_ref,created_at,expires_at,due_at,epoch)
 VALUES($1::uuid,$2::uuid,$3,$4::uuid,$5,$6::uuid,$7::uuid,$8,$9::uuid,$10,$11,$12,$13)
 ON CONFLICT(kind,message_id,account_id,binding_id)DO NOTHING`, in.ID, node.ID, node.Generation, account, in.Kind, in.ConversationID, in.MessageID, template, group, in.CreatedAt, in.ExpiresAt, now.Add(time.Second), in.Epoch)
	if err != nil {
		return 0, err
	}
	return int(result.RowsAffected()), nil
}
