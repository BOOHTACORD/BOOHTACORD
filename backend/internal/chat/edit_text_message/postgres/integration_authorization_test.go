package edittextmessagepostgres

import (
	"errors"
	"testing"

	edit "voice-platform/backend/internal/chat/edit_text_message"
)

func TestPostgresEditAuthorization(t *testing.T) {
	for _, scenario := range []string{"author", "foreign_author", "stale_revision", "archived_channel", "wrong_channel", "voice_channel", "deleted_message"} {
		t.Run(scenario, func(t *testing.T) {
			f := newEditFixture(t)
			input := edit.Input{ActorID: f.author, ChannelID: f.channel, MessageID: f.message, Body: "changed", ExpectedRevision: 1}
			switch scenario {
			case "foreign_author":
				input.ActorID = f.outsider
			case "stale_revision":
				input.ExpectedRevision = 2
			case "archived_channel":
				f.exec(t, "UPDATE channels SET archived_at=now() WHERE id=$1", f.channel)
			case "wrong_channel":
				input.ChannelID = f.other
			case "voice_channel":
				f.exec(t, "UPDATE channels SET kind='VOICE' WHERE id=$1", f.channel)
			case "deleted_message":
				f.exec(t, "UPDATE messages SET deleted_at=now(),body='' WHERE id=$1", f.message)
			}
			before := f.snapshot(t)
			result, err := New(NewPoolDatabase(f.pool)).Edit(t.Context(), edit.Request{Input: input})
			if scenario != "author" {
				if !errors.Is(err, edit.ErrConflict) {
					t.Errorf("denied edit returned %v", err)
				}
				if f.snapshot(t) != before {
					t.Error("denied edit changed persisted message")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			if result.Body != "changed" || result.Revision != 2 || result.AuthorID != f.author || result.EditedAt.IsZero() {
				t.Error("allowed edit did not return the persisted revision")
			}
			var body string
			var revision int
			if err := f.pool.QueryRow(t.Context(), "SELECT body,revision FROM messages WHERE id=$1", f.message).Scan(&body, &revision); err != nil {
				t.Fatal(err)
			}
			if body != "changed" || revision != 2 {
				t.Error("allowed edit was not persisted")
			}
		})
	}
}
