package publishscreendescriptorpostgres

import (
	"errors"
	"testing"

	publish "voice-platform/backend/internal/media/publish_screen_descriptor"
)

func TestPostgresDescriptorAdmission(t *testing.T) {
	for _, scenario := range []string{"active", "revoked_session", "revoked_lease", "closed_channel", "archived_channel", "text_channel", "blocked_account", "foreign_account", "foreign_session"} {
		t.Run(scenario, func(t *testing.T) {
			f := newDescriptorFixture(t)
			principal := publish.Principal{AccountID: testAccount}
			switch scenario {
			case "revoked_session":
				f.exec(t, "UPDATE sessions SET revoked_at=now() WHERE user_id=$1", testAccount)
			case "revoked_lease":
				f.exec(t, "UPDATE voice_leases SET revoked_at=now(),revocation_reason='SESSION_REVOKED' WHERE id=$1", testLease)
			case "closed_channel":
				f.exec(t, "UPDATE channels SET admission_closed_at=now() WHERE id=$1", testChannel)
			case "archived_channel":
				f.exec(t, "UPDATE channels SET archived_at=now() WHERE id=$1", testChannel)
			case "text_channel":
				f.exec(t, "UPDATE channels SET kind='TEXT' WHERE id=$1", testChannel)
			case "blocked_account":
				f.exec(t, "UPDATE users SET blocked_at=now() WHERE id=$1", testAccount)
			case "foreign_account":
				principal.AccountID = foreignAccount
			case "foreign_session":
				principal.SessionDigest[0] = 1
			}
			before := f.snapshot(t)
			publisher := &fakePublisher{}
			err := New(NewPoolDatabase(f.pool), publisher).Apply(t.Context(), principal, testLease, "https://voice.example.test", testDescriptor())
			if scenario != "active" {
				if !errors.Is(err, publish.ErrDenied) {
					t.Errorf("denied descriptor returned %v", err)
				}
				if publisher.calls != 0 {
					t.Error("denied descriptor reached publisher")
				}
				if f.snapshot(t) != before {
					t.Error("denied descriptor changed receipt")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			var revision int64
			var hash []byte
			if err := f.pool.QueryRow(t.Context(), "SELECT screen_profile_operation_revision,screen_profile_operation_hash FROM voice_leases WHERE id=$1", testLease).Scan(&revision, &hash); err != nil {
				t.Fatal(err)
			}
			if publisher.calls != 1 || publisher.lease != testLease || publisher.channel != testChannel || revision != 1 || len(hash) != 32 {
				t.Error("active descriptor did not publish and persist its receipt")
			}
		})
	}
}
