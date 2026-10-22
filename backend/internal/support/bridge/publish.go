package supportbridge

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"strconv"
	"strings"
	"unicode/utf8"
	files "voice-platform/backend/internal/storage/download_text_attachment"
)

func (w Worker) publish(ctx context.Context, job queued) error {
	job.Operation = w.client.opaque("message", job.id)
	job.Conversation = w.client.opaque("conversation", job.dm)
	for index := range job.Files {
		item := &job.Files[index]
		reader, err := w.files.Open(item.key, item.Size)
		if err != nil {
			return ErrGateway
		}
		body, err := io.ReadAll(io.LimitReader(reader, files.MaxAttachmentBytes+1))
		reader.Close()
		if err != nil || int64(len(body)) != item.Size {
			return ErrGateway
		}
		digest := sha256.Sum256(body)
		item.SHA256 = hex.EncodeToString(digest[:])
		item.Name = strings.Map(func(r rune) rune {
			if r == '/' || r == '\\' || r == '\n' || r == '\r' || r == 0 {
				return '_'
			}
			return r
		}, item.Name)
		if utf8.RuneCountInString(item.Name) > 128 {
			item.Name = string([]rune(item.Name)[:128])
		}
		if item.Name == "." || item.Name == ".." {
			item.Name = "attachment"
		}
		if err = w.client.request(ctx, "PUT", "/blobs/"+job.Operation+"/"+strconv.Itoa(index), body, nil); err != nil {
			return err
		}
	}
	if _, err := w.db.Exec(ctx, `INSERT INTO support_public_routes(conversation,direct_message_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, job.Conversation, job.dm); err != nil {
		return ErrGateway
	}
	body, err := encode(job.publication)
	if err != nil {
		return ErrGateway
	}
	if err = w.client.request(ctx, "POST", "/messages", body, nil); err != nil {
		return err
	}
	if _, err = w.db.Exec(ctx, `UPDATE support_public_outbox SET delivered_at=now() WHERE id=$1`, job.id); err != nil {
		return ErrGateway
	}
	return nil
}
