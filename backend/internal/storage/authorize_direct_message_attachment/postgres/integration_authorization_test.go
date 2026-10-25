package authorizedirectmessageattachmentpostgres

import (
	"errors"
	"testing"

	"github.com/google/uuid"
	authorize "voice-platform/backend/internal/storage/authorize_direct_message_attachment"
)

func TestPostgresAttachmentPairAuthorization(t *testing.T) {
	for _, scenario := range []string{"first", "second", "outsider", "outsider_administrator", "blocked_first", "blocked_second", "missing_pair"} {
		t.Run(scenario, func(t *testing.T) {
			f := newAttachmentFixture(t)
			input := authorize.Input{ActorID: participantOne, DirectMessageID: pair}
			switch scenario {
			case "second":
				input.ActorID = participantTwo
			case "outsider":
				input.ActorID = outsider
			case "outsider_administrator":
				input.ActorID = administrator
			case "blocked_first":
				f.exec(t, "UPDATE users SET blocked_at=now() WHERE id=$1", participantOne)
			case "blocked_second":
				f.exec(t, "UPDATE users SET blocked_at=now() WHERE id=$1", participantTwo)
			case "missing_pair":
				input.DirectMessageID = uuid.NewString()
			}
			before := f.snapshot(t)
			err := New(NewPoolDatabase(f.pool)).Authorize(t.Context(), input)
			if scenario == "first" || scenario == "second" {
				if err != nil {
					t.Fatal(err)
				}
			} else if !errors.Is(err, authorize.ErrTargetUnavailable) {
				t.Errorf("denied authorization returned %v", err)
			}
			if f.snapshot(t) != before {
				t.Error("authorization changed persisted state")
			}
		})
	}
}
