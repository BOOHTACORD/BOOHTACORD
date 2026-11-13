package listtopologypostgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgtype"
	listtopology "voice-platform/backend/internal/channel/list_topology"
)

const selectRevision = `SELECT COALESCE((SELECT revision FROM channel_topology_state WHERE singleton = TRUE), 0)`
const selectTopology = `
SELECT category.id::text, category.name, category.position,
       channel.id::text, channel.name, channel.description, channel.kind, channel.position, channel.admission_closed_at IS NOT NULL,
       CASE WHEN channel.kind = 'TEXT' THEN unread.unread_count END AS unread_count,
       CASE WHEN channel.kind = 'TEXT' THEN unread.mention_count END AS mention_count,
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
LEFT JOIN LATERAL (
    SELECT COUNT(*) AS unread_count,
           COUNT(*) FILTER (WHERE $1::uuid = ANY(message.mention_user_ids)) AS mention_count
    FROM messages AS message
    LEFT JOIN channel_read_cursors AS cursor
      ON cursor.account_id = $1::uuid AND cursor.channel_id = channel.id
    WHERE channel.kind = 'TEXT'
      AND message.channel_id = channel.id
      AND message.deleted_at IS NULL
      AND message.author_id <> $1::uuid
      AND (cursor.message_id IS NULL OR
           (message.created_at, message.id) > (cursor.message_created_at, cursor.message_id))
) AS unread ON TRUE
ORDER BY category.position, channel.position`

type Row interface{ Scan(...any) error }
type Rows interface {
	Next() bool
	Scan(...any) error
	Close()
	Err() error
}
type Database interface {
	QueryRow(context.Context, string, ...any) Row
	Query(context.Context, string, ...any) (Rows, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) List(context context.Context, request listtopology.Request) (listtopology.Result, error) {
	var result listtopology.Result
	if err := repository.database.QueryRow(context, selectRevision).Scan(&result.Revision); err != nil {
		return result, fmt.Errorf("select topology revision: %w", err)
	}
	rows, err := repository.database.Query(context, selectTopology, request.ActorID)
	if err != nil {
		return result, fmt.Errorf("select channel topology: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var category listtopology.Category
		var channelID, channelName, channelDescription, channelKind pgtype.Text
		var channelPosition pgtype.Int4
		var admissionClosed pgtype.Bool
		var unreadCount pgtype.Int8
		var mentionCount pgtype.Int8
		var firstUnreadID pgtype.Text
		if err := rows.Scan(&category.ID, &category.Name, &category.Position, &channelID, &channelName, &channelDescription, &channelKind, &channelPosition, &admissionClosed, &unreadCount, &mentionCount, &firstUnreadID); err != nil {
			return result, fmt.Errorf("scan channel topology: %w", err)
		}
		if len(result.Categories) == 0 || result.Categories[len(result.Categories)-1].ID != category.ID {
			result.Categories = append(result.Categories, category)
		}
		if channelID.Valid {
			last := &result.Categories[len(result.Categories)-1]
			last.Channels = append(last.Channels, listtopology.Channel{ID: channelID.String, Name: channelName.String, Description: channelDescription.String, Kind: channelKind.String, Position: int(channelPosition.Int32), AdmissionClosed: admissionClosed.Bool, UnreadCount: unreadCount.Int64, MentionCount: mentionCount.Int64, FirstUnreadMessageID: firstUnreadID.String})
		}
	}
	if err := rows.Err(); err != nil {
		return result, fmt.Errorf("iterate channel topology: %w", err)
	}
	return result, nil
}
