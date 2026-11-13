package listtopologypostgres

const legacySelectTopology = `
SELECT category.id::text, category.name, category.position,
       channel.id::text, channel.name, channel.description, channel.kind, channel.position, channel.admission_closed_at IS NOT NULL,
       CASE WHEN channel.kind = 'TEXT' THEN (
           SELECT COUNT(*)
           FROM messages AS message
           LEFT JOIN channel_read_cursors AS cursor
             ON cursor.account_id = $1::uuid AND cursor.channel_id = channel.id
           WHERE message.channel_id = channel.id
             AND message.deleted_at IS NULL
             AND message.author_id <> $1::uuid
             AND (cursor.message_id IS NULL OR
                  (message.created_at, message.id) > (cursor.message_created_at, cursor.message_id))
       ) END AS unread_count,
       CASE WHEN channel.kind = 'TEXT' THEN (
           SELECT COUNT(*)
           FROM messages AS message
           LEFT JOIN channel_read_cursors AS cursor
             ON cursor.account_id = $1::uuid AND cursor.channel_id = channel.id
           WHERE message.channel_id = channel.id
             AND message.deleted_at IS NULL
             AND message.author_id <> $1::uuid
             AND $1::uuid = ANY(message.mention_user_ids)
             AND (cursor.message_id IS NULL OR
                  (message.created_at, message.id) > (cursor.message_created_at, cursor.message_id))
       ) END AS mention_count,
       CASE WHEN channel.kind = 'TEXT' THEN (
           SELECT message.id::text
           FROM messages AS message
           LEFT JOIN channel_read_cursors AS cursor
             ON cursor.account_id = $1::uuid AND cursor.channel_id = channel.id
           WHERE message.channel_id = channel.id
             AND message.deleted_at IS NULL
             AND message.author_id <> $1::uuid
             AND (cursor.message_id IS NULL OR
                  (message.created_at, message.id) > (cursor.message_created_at, cursor.message_id))
           ORDER BY message.created_at, message.id
           LIMIT 1
       ) END AS first_unread_message_id
FROM categories AS category
LEFT JOIN channels AS channel ON channel.category_id = category.id AND channel.archived_at IS NULL
ORDER BY category.position, channel.position`
