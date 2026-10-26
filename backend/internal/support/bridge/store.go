package supportbridge

import (
	"context"
	"encoding/json"
	"github.com/jackc/pgx/v5/pgxpool"
)

type file struct {
	Name   string `json:"name"`
	Size   int64  `json:"size"`
	SHA256 string `json:"sha256"`
	key    string
}
type publication struct {
	Operation    string `json:"operation_id"`
	Conversation string `json:"conversation"`
	UserID       string `json:"user_id"`
	Body         string `json:"body"`
	Consent      int    `json:"consent_version"`
	Files        []file `json:"files"`
}
type queued struct {
	id, dm string
	publication
}

func next(ctx context.Context, db *pgxpool.Pool) (queued, error) {
	var job queued
	err := db.QueryRow(ctx, `SELECT o.id::text,m.direct_message_id::text,m.author_id::text,o.body,o.notice_version
 FROM support_public_outbox o JOIN direct_message_messages m ON m.id=o.message_id
 JOIN support_product_identity p ON true JOIN support_contact_configuration c ON c.mode='product' AND c.support_account_id=p.account_id
 JOIN support_public_consents consent ON consent.user_id=m.author_id AND consent.notice_version=o.notice_version
 JOIN direct_messages dm ON dm.id=m.direct_message_id AND p.account_id IN(dm.participant_one_id,dm.participant_two_id)
 JOIN users u ON u.id=m.author_id AND u.blocked_at IS NULL
 WHERE o.delivered_at IS NULL AND o.cancelled_at IS NULL AND m.deleted_at IS NULL AND o.notice_version=p.notice_version
 ORDER BY o.created_at,o.id LIMIT 1`).Scan(&job.id, &job.dm, &job.UserID, &job.Body, &job.Consent)
	if err != nil {
		return queued{}, err
	}
	job.Files = []file{}
	rows, err := db.Query(ctx, `SELECT a.original_name,a.byte_size,a.storage_key::text FROM support_public_outbox o
 JOIN direct_message_attachments link ON link.message_id=o.message_id JOIN attachments a ON a.id=link.attachment_id
 WHERE o.id=$1 AND a.state='ATTACHED' ORDER BY link.position`, job.id)
	if err != nil {
		return queued{}, err
	}
	defer rows.Close()
	for rows.Next() {
		var value file
		if err = rows.Scan(&value.Name, &value.Size, &value.key); err != nil {
			return queued{}, err
		}
		job.Files = append(job.Files, value)
	}
	return job, rows.Err()
}
func encode(value any) ([]byte, error) { return json.Marshal(value) }
