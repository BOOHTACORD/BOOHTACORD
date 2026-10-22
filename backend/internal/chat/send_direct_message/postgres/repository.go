package senddirectmessagepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	senddirectmessage "voice-platform/backend/internal/chat/send_direct_message"
	flowstage "voice-platform/backend/internal/observability/flow_stage"
)

const insertDirectMessage = `
WITH active_pair AS (
    SELECT dm.id FROM direct_messages dm
    JOIN users one ON one.id = dm.participant_one_id
    JOIN users two ON two.id = dm.participant_two_id
    WHERE dm.id = $2
      AND $3::uuid IN (dm.participant_one_id, dm.participant_two_id)
      AND one.blocked_at IS NULL AND two.blocked_at IS NULL
    FOR SHARE OF one, two
), existing_message AS (
    SELECT m.id::text, m.direct_message_id::text, m.author_id::text,
           m.client_message_id::text, m.body, COALESCE(m.reply_to_id::text, ''),
           m.revision, m.created_at, m.mention_user_ids::text[]
    FROM direct_message_messages m JOIN active_pair ON active_pair.id = m.direct_message_id
    WHERE m.author_id = $3 AND m.client_message_id = $4
), requested_attachments AS (
    SELECT attachment_id, position - 1 AS position
    FROM unnest($7::uuid[]) WITH ORDINALITY AS requested(attachment_id, position)
), valid_attachments AS (
    SELECT requested.attachment_id, requested.position
    FROM requested_attachments requested
    JOIN attachments attachment ON attachment.id = requested.attachment_id
    JOIN active_pair ON true
    WHERE attachment.owner_id = $3
      AND attachment.direct_message_id = active_pair.id
      AND attachment.state = 'UNATTACHED'
      AND NOT EXISTS (SELECT 1 FROM existing_message)
    FOR UPDATE OF attachment
), attachments_valid AS (
    SELECT (SELECT count(*) FROM requested_attachments) = (SELECT count(*) FROM valid_attachments) AS value
), valid_mentions AS (
    SELECT target.id FROM direct_messages AS dm
    JOIN active_pair ON active_pair.id = dm.id
    JOIN users AS target ON target.id = CASE WHEN dm.participant_one_id = $3::uuid THEN dm.participant_two_id ELSE dm.participant_one_id END
    WHERE target.id = ANY($8::uuid[]) AND target.blocked_at IS NULL
    FOR SHARE OF target
), inserted AS (
    INSERT INTO direct_message_messages (id, direct_message_id, author_id, client_message_id, body, reply_to_id, mention_user_ids)
    SELECT $1::uuid, active_pair.id, $3::uuid, $4::uuid, $5, $6::uuid, $8::uuid[] FROM active_pair
    WHERE NOT EXISTS (SELECT 1 FROM existing_message)
      AND ($5 <> '' OR cardinality($7::uuid[]) > 0)
      AND (SELECT value FROM attachments_valid)
      AND (SELECT count(*) FROM valid_mentions) = cardinality($8::uuid[])
      AND ($6::uuid IS NULL OR EXISTS (
        SELECT 1 FROM direct_message_messages reply
        WHERE reply.id = $6::uuid AND reply.direct_message_id = active_pair.id
      ))
    ON CONFLICT (author_id, direct_message_id, client_message_id) DO NOTHING
    RETURNING id::text, direct_message_id::text, author_id::text, client_message_id::text, body, COALESCE(reply_to_id::text, ''), revision, created_at, mention_user_ids::text[]
), linked AS (
    INSERT INTO direct_message_attachments (message_id, attachment_id, position)
    SELECT inserted.id::uuid, valid_attachments.attachment_id, valid_attachments.position
    FROM inserted CROSS JOIN valid_attachments
    RETURNING attachment_id
), updated AS (
    UPDATE attachments AS attachment
    SET state = 'ATTACHED', attached_at = now()
    FROM linked
    WHERE attachment.id = linked.attachment_id
    RETURNING attachment.id
)
SELECT * FROM existing_message
UNION ALL
SELECT * FROM inserted
WHERE (SELECT count(*) FROM updated) = (SELECT count(*) FROM valid_attachments)`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Send(context context.Context, request senddirectmessage.Request) (result senddirectmessage.Result, err error) {
	context, span := flowstage.Begin(context, "message.store", "dependency")
	defer func() { flowstage.End(span, err) }()
	var replyTo any
	if request.ReplyToID != "" {
		replyTo = request.ReplyToID
	}
	mentions := append([]string{}, request.MentionUserIDs...)
	err = repository.database.QueryRow(context, insertDirectMessage, request.ID, request.DirectMessageID, request.ActorID, request.ClientMessageID, request.Body, replyTo, request.AttachmentIDs, mentions).Scan(
		&result.ID, &result.DirectMessageID, &result.AuthorID, &result.ClientMessageID, &result.Body, &result.ReplyToID, &result.Revision, &result.CreatedAt, &result.MentionUserIDs,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		var committed senddirectmessage.Result
		lookupErr := repository.database.QueryRow(context, selectCommittedMessage, request.ActorID, request.DirectMessageID, request.ClientMessageID).Scan(&committed.ID, &committed.DirectMessageID, &committed.AuthorID, &committed.ClientMessageID, &committed.Body, &committed.ReplyToID, &committed.Revision, &committed.CreatedAt, &committed.MentionUserIDs)
		if lookupErr == nil {
			flowstage.Storage(context, "replayed")
			return committed, nil
		}
		if lookupErr != nil && !errors.Is(lookupErr, pgx.ErrNoRows) {
			return senddirectmessage.Result{}, fmt.Errorf("read committed direct message: %w", lookupErr)
		}
		return senddirectmessage.Result{}, senddirectmessage.ErrDirectMessageUnavailable
	}
	if err != nil {
		var denied *pgconn.PgError
		if errors.As(err, &denied) && denied.Code == "42501" {
			return senddirectmessage.Result{}, senddirectmessage.ErrDirectMessageUnavailable
		}
		return senddirectmessage.Result{}, fmt.Errorf("insert direct message: %w", err)
	}
	if result.ID == request.ID {
		flowstage.Storage(context, "committed")
	} else {
		flowstage.Storage(context, "replayed")
	}
	return result, nil
}
