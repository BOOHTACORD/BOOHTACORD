package supportbridge

import (
	"context"
	"github.com/google/uuid"
	"strconv"
	"strings"
	"unicode/utf8"
	send "voice-platform/backend/internal/chat/send_direct_message"
)

func (w Worker) receive(ctx context.Context) error {
	var cursor int64
	if err := w.db.QueryRow(ctx, `SELECT reply_cursor FROM support_product_identity WHERE singleton=true`).Scan(&cursor); err != nil {
		return ErrGateway
	}
	var result struct {
		Replies []struct {
			ID           int64  `json:"id"`
			Conversation string `json:"conversation"`
			Body         string `json:"body"`
		} `json:"replies"`
	}
	if err := w.client.request(ctx, "GET", "/replies?after="+strconv.FormatInt(cursor, 10), nil, &result); err != nil {
		return err
	}
	if len(result.Replies) > 100 {
		return ErrGateway
	}
	for _, reply := range result.Replies {
		if reply.ID <= cursor || len(reply.Conversation) != 32 || reply.Body == "" || utf8.RuneCountInString(reply.Body) > 8000 || strings.ContainsRune(reply.Body, 0) {
			return ErrGateway
		}
		var dm string
		if err := w.db.QueryRow(ctx, `SELECT r.direct_message_id::text FROM support_public_routes r
   JOIN direct_messages dm ON dm.id=r.direct_message_id AND $2::uuid IN(dm.participant_one_id,dm.participant_two_id)
   WHERE r.conversation=$1`, reply.Conversation, w.peer).Scan(&dm); err != nil {
			return ErrGateway
		}
		clientID := uuid.NewSHA1(uuid.NameSpaceOID, []byte(w.client.opaque("reply", strconv.FormatInt(reply.ID, 10)))).String()
		if _, err := w.sender.Send(ctx, send.Input{ActorID: w.peer, DirectMessageID: dm, ClientMessageID: clientID, Body: reply.Body}); err != nil {
			return ErrGateway
		}
		if _, err := w.db.Exec(ctx, `UPDATE support_product_identity SET reply_cursor=$1 WHERE singleton=true AND reply_cursor<$1`, reply.ID); err != nil {
			return ErrGateway
		}
		cursor = reply.ID
	}
	return nil
}
