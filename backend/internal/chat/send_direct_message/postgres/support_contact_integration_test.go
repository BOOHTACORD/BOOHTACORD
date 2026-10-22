package senddirectmessagepostgres

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"testing"
	history "voice-platform/backend/internal/chat/list_direct_message_history"
	historypg "voice-platform/backend/internal/chat/list_direct_message_history/postgres"
	list "voice-platform/backend/internal/chat/list_direct_messages"
	listpg "voice-platform/backend/internal/chat/list_direct_messages/postgres"
	open "voice-platform/backend/internal/chat/open_direct_message"
	openpg "voice-platform/backend/internal/chat/open_direct_message/postgres"
	send "voice-platform/backend/internal/chat/send_direct_message"
	download "voice-platform/backend/internal/storage/download_direct_message_attachment"
	downloadpg "voice-platform/backend/internal/storage/download_direct_message_attachment/postgres"
	support "voice-platform/backend/internal/support/contact"
)

func TestSupportContactUsesOnlyOrdinaryPairsAndCannotTransferHistory(t *testing.T) {
	f := newDMFixture(t)
	ctx := context.Background()
	config := support.New(f.pool)
	if _, err := config.Assign(ctx, f.peer); err != nil {
		t.Fatal("active support assignment failed")
	}
	opener := open.New(openpg.New(openpg.NewPoolDatabase(f.pool)))
	pairA, err := opener.Open(ctx, open.Input{ActorID: f.actor, ParticipantID: f.peer})
	if err != nil {
		t.Fatal("open A support")
	}
	pairB, err := opener.Open(ctx, open.Input{ActorID: f.outsider, ParticipantID: f.peer})
	if err != nil || pairA.ID == pairB.ID {
		t.Fatal("support pairs collided")
	}
	repeat, err := opener.Open(ctx, open.Input{ActorID: f.actor, ParticipantID: f.peer})
	if err != nil || repeat.ID != pairA.ID {
		t.Fatal("support pair not reused")
	}
	self, _ := config.Resolve(ctx, f.peer)
	if self.State != "self" || self.AccountID != "" {
		t.Fatal("support self contact actionable")
	}
	sender := send.New(New(NewPoolDatabase(f.pool)))
	client := uuid.NewString()
	original, err := sender.Send(ctx, send.Input{ActorID: f.actor, DirectMessageID: pairA.ID, ClientMessageID: client, Body: "synthetic A support", AttachmentIDs: []string{f.attachment}})
	if err != nil {
		t.Fatal("ordinary support attachment send failed")
	}
	repeated, err := sender.Send(ctx, send.Input{ActorID: f.actor, DirectMessageID: pairA.ID, ClientMessageID: client, Body: "synthetic A support", AttachmentIDs: []string{f.attachment}})
	if err != nil || repeated.ID != original.ID {
		t.Fatal("support broke client-message dedup")
	}
	if _, err := sender.Send(ctx, send.Input{ActorID: f.outsider, DirectMessageID: pairB.ID, ClientMessageID: uuid.NewString(), Body: "synthetic B support"}); err != nil {
		t.Fatal("ordinary B support send failed")
	}
	for _, pair := range []string{pairA.ID, pairB.ID} {
		if _, err := sender.Send(ctx, send.Input{ActorID: f.peer, DirectMessageID: pair, ClientMessageID: uuid.NewString(), Body: "synthetic operator reply"}); err != nil {
			t.Fatal("operator cannot reply as ordinary participant")
		}
	}
	reader := history.New(historypg.New(historypg.NewPoolDatabase(f.pool)))
	for _, row := range []struct{ actor, pair string }{{f.actor, pairA.ID}, {f.outsider, pairB.ID}} {
		page, err := reader.List(ctx, history.Input{ActorID: row.actor, DirectMessageID: row.pair, Limit: 10})
		if err != nil || len(page.Messages) != 2 {
			t.Fatal("support pair history invalid")
		}
	}
	if _, err := reader.List(ctx, history.Input{ActorID: f.outsider, DirectMessageID: pairA.ID, Limit: 10}); !errors.Is(err, history.ErrDirectMessageUnavailable) {
		t.Fatal("other administrator read private support")
	}
	files := downloadpg.New(downloadpg.NewPoolDatabase(f.pool))
	if _, err := files.Find(ctx, download.Input{ActorID: f.peer, DirectMessageID: pairA.ID, AttachmentID: f.attachment}); err != nil {
		t.Fatal("operator lost attachment ACL")
	}
	if _, err := files.Find(ctx, download.Input{ActorID: f.outsider, DirectMessageID: pairA.ID, AttachmentID: f.attachment}); !errors.Is(err, download.ErrAttachmentUnavailable) {
		t.Fatal("attachment UUID bypassed support pair ACL")
	}
	nav := list.New(listpg.New(listpg.NewPoolDatabase(f.pool)))
	navigation, err := nav.List(ctx, list.Input{ActorID: f.peer})
	if err != nil || len(navigation.DirectMessages) != 2 {
		t.Fatal("operator ordinary DM navigation missing")
	}
	if _, err := config.Assign(ctx, f.outsider); err != nil {
		t.Fatal("replace support")
	}
	replacement, _ := config.Resolve(ctx, f.actor)
	if replacement.AccountID != f.outsider {
		t.Fatal("support replacement not visible")
	}
	if _, err := reader.List(ctx, history.Input{ActorID: f.outsider, DirectMessageID: pairA.ID, Limit: 10}); !errors.Is(err, history.ErrDirectMessageUnavailable) {
		t.Fatal("replacement inherited private history")
	}
	newPair, err := opener.Open(ctx, open.Input{ActorID: f.actor, ParticipantID: replacement.AccountID})
	if err != nil || newPair.ID == pairA.ID {
		t.Fatal("replacement rewrote old pair")
	}
	if _, err := f.pool.Exec(ctx, `UPDATE users SET blocked_at=now() WHERE id=$1`, f.outsider); err != nil {
		t.Fatal(err)
	}
	blocked, _ := config.Resolve(ctx, f.actor)
	if blocked.State != "unavailable" || blocked.AccountID != "" {
		t.Fatal("blocked operator remains pinned")
	}
	if _, err := sender.Send(ctx, send.Input{ActorID: f.actor, DirectMessageID: newPair.ID, ClientMessageID: uuid.NewString(), Body: "synthetic blocked target"}); !errors.Is(err, send.ErrDirectMessageUnavailable) {
		t.Fatal("blocked support accepted message")
	}
	if _, err := config.Assign(ctx, f.outsider); !errors.Is(err, support.ErrUnavailable) {
		t.Fatal("blocked support could be assigned")
	}
	if _, err := config.Assign(ctx, ""); err != nil {
		t.Fatal("clear support")
	}
	cleared, _ := config.Resolve(ctx, f.actor)
	if cleared.State != "not_configured" {
		t.Fatal("clear not persisted")
	}
	var audits int
	if err := f.pool.QueryRow(ctx, `SELECT count(*) FROM audit_events WHERE event_type='SUPPORT_CONTACT_CHANGED'`).Scan(&audits); err != nil || audits != 3 {
		t.Fatal("support configuration metadata audit invalid")
	}
}
