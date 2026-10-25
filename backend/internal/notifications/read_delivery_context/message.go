package readdeliverycontext

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
)

var ErrUnavailable = errors.New("notification target unavailable")

type Database interface {
	QueryRow(context.Context, string, ...any) pgx.Row
	Query(context.Context, string, ...any) (pgx.Rows, error)
}
type Reader struct{ database Database }

func New(database Database) Reader { return Reader{database} }

type Message struct {
	ID, ConversationID, AuthorID, Kind string
	Mentions                           []string
	CreatedAt                          time.Time
	Deleted, Archived, AuthorBlocked   bool
}

const textMessage = `SELECT m.id::text,m.channel_id::text,m.author_id::text,m.mention_user_ids,m.created_at,m.deleted_at IS NOT NULL,c.archived_at IS NOT NULL,u.blocked_at IS NOT NULL
 FROM messages m JOIN channels c ON c.id=m.channel_id JOIN users u ON u.id=m.author_id WHERE m.id=$1::uuid AND m.kind='USER' AND c.kind='TEXT'`
const directMessage = `SELECT m.id::text,m.direct_message_id::text,m.author_id::text,m.mention_user_ids,m.created_at,m.deleted_at IS NOT NULL,false,
 u.blocked_at IS NOT NULL OR m.author_id NOT IN(dm.participant_one_id,dm.participant_two_id)
 FROM direct_message_messages m JOIN direct_messages dm ON dm.id=m.direct_message_id JOIN users u ON u.id=m.author_id WHERE m.id=$1::uuid`

func (r Reader) Message(ctx context.Context, kind, id string) (Message, error) {
	query := textMessage
	if kind == "DM" {
		query = directMessage
	} else if kind != "TEXT" {
		return Message{}, ErrUnavailable
	}
	m := Message{Kind: kind}
	err := r.database.QueryRow(ctx, query, id).Scan(&m.ID, &m.ConversationID, &m.AuthorID, &m.Mentions, &m.CreatedAt, &m.Deleted, &m.Archived, &m.AuthorBlocked)
	if errors.Is(err, pgx.ErrNoRows) {
		return m, ErrUnavailable
	}
	return m, err
}
func VerifiedMention(original, current []string, recipient string) bool {
	found := false
	for _, id := range original {
		if id == recipient {
			found = true
			break
		}
	}
	if !found {
		return false
	}
	for _, id := range current {
		if id == recipient {
			return true
		}
	}
	return false
}
