package listtextmessagespostgres

import "strings"

const selectChannel = `SELECT EXISTS(SELECT 1 FROM channels WHERE id = $1 AND kind = 'TEXT' AND archived_at IS NULL)`
const selectMessages = `
WITH cursor AS (
    SELECT created_at, id FROM messages WHERE id = $2 AND channel_id = $1
), page AS MATERIALIZED (
    SELECT messages.* FROM messages
    WHERE messages.channel_id = $1
      AND ($2::uuid IS NULL OR (messages.created_at, messages.id) < (SELECT created_at, id FROM cursor)
           OR ($4::bool AND messages.id = $2::uuid))
    ORDER BY messages.created_at DESC, messages.id DESC
    LIMIT $3
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
FROM page AS messages
LEFT JOIN message_attachments ON message_attachments.message_id = messages.id
LEFT JOIN attachments ON attachments.id = message_attachments.attachment_id AND attachments.state = 'ATTACHED'
GROUP BY messages.id, messages.channel_id, messages.author_id, messages.client_message_id, messages.body, messages.reply_to_id, messages.created_at, messages.edited_at, messages.revision, messages.deleted_at, messages.mention_user_ids, messages.kind
ORDER BY messages.created_at DESC, messages.id DESC`

func historyQuery(after bool) string {
	if !after {
		return selectMessages
	}
	query := strings.Replace(selectMessages, "(messages.created_at, messages.id) <", "(messages.created_at, messages.id) >", 1)
	return strings.ReplaceAll(query, "ORDER BY messages.created_at DESC, messages.id DESC", "ORDER BY messages.created_at ASC, messages.id ASC")
}
