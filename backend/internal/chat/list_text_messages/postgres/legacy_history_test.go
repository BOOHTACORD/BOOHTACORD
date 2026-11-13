package listtextmessagespostgres

import "strings"

// Frozen pre-optimization statement for behavior comparison on disposable PostgreSQL.
const legacyHistory = `
WITH cursor AS (
    SELECT created_at, id FROM messages WHERE id = $2 AND channel_id = $1
)
SELECT messages.id::text, messages.channel_id::text, messages.author_id::text, messages.client_message_id::text,
       CASE WHEN messages.deleted_at IS NULL THEN messages.body ELSE '' END, COALESCE(messages.reply_to_id::text, ''), messages.created_at, messages.edited_at, messages.revision, messages.deleted_at IS NOT NULL,
       CASE WHEN messages.deleted_at IS NULL THEN messages.mention_user_ids::text[] ELSE ARRAY[]::text[] END,
       COALESCE(
           jsonb_agg(
               jsonb_build_object('id', attachments.id::text, 'original_name', attachments.original_name, 'byte_size', attachments.byte_size)
               ORDER BY message_attachments.position
           ) FILTER (WHERE attachments.id IS NOT NULL AND messages.deleted_at IS NULL),
           '[]'::jsonb
       )::text, messages.kind
FROM messages
LEFT JOIN message_attachments ON message_attachments.message_id = messages.id
LEFT JOIN attachments ON attachments.id = message_attachments.attachment_id AND attachments.state = 'ATTACHED'
WHERE messages.channel_id = $1
  AND ($2::uuid IS NULL OR (messages.created_at, messages.id) < (SELECT created_at, id FROM cursor)
       OR ($4::bool AND messages.id = $2::uuid))
GROUP BY messages.id, messages.channel_id, messages.author_id, messages.client_message_id, messages.body, messages.reply_to_id, messages.created_at, messages.edited_at, messages.revision, messages.deleted_at
ORDER BY messages.created_at DESC, messages.id DESC
LIMIT $3`

func legacyHistoryQuery(after, archived bool) string {
	query := legacyHistory
	if after {
		query = strings.Replace(query, "(messages.created_at, messages.id) <", "(messages.created_at, messages.id) >", 1)
		query = strings.Replace(query, "ORDER BY messages.created_at DESC, messages.id DESC", "ORDER BY messages.created_at ASC, messages.id ASC", 1)
	}
	if archived {
		query = strings.Replace(query, "WHERE messages.channel_id = $1", `WHERE messages.channel_id = $1
  AND EXISTS(SELECT 1 FROM channels JOIN users ON users.id=$5
    WHERE channels.id=$1 AND channels.kind='TEXT' AND channels.archived_at IS NOT NULL
    AND channels.readonly_archive AND users.blocked_at IS NULL)`, 1)
	}
	return query
}
