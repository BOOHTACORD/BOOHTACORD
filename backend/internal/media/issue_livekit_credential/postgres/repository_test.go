package issuelivekitcredentialpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	issuelivekitcredential "voice-platform/backend/internal/media/issue_livekit_credential"
)

func TestRepositoryRequiresCurrentLeaseChannelSessionAndAccount(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"lease-1", "voice-1", "Егор 🎮", "", "", true}}}
	lease, err := New(database).FindActive(context.Background(), issuelivekitcredential.Input{ActorID: "user-1", LeaseID: "lease-1", SessionDigest: sha256.Sum256([]byte("session"))})
	if err != nil || lease != (issuelivekitcredential.Lease{ID: "lease-1", ChannelID: "voice-1", DisplayName: "Егор 🎮", MicrophoneAllowed: true}) || !strings.Contains(database.statement, "account.display_name") || !strings.Contains(database.statement, "channel.admission_closed_at IS NULL") || !strings.Contains(database.statement, "session.revoked_at IS NULL") || !strings.Contains(database.statement, "account.blocked_at IS NULL") {
		t.Fatalf("error = %v, lease = %#v, statement = %s", err, lease, database.statement)
	}
}
func TestRepositoryMapsRevokedOrMissingLeaseToUnavailable(t *testing.T) {
	_, err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).FindActive(context.Background(), issuelivekitcredential.Input{})
	if !errors.Is(err, issuelivekitcredential.ErrLeaseUnavailable) {
		t.Fatalf("error = %v", err)
	}
}

type fakeDatabase struct {
	row       fakeRow
	statement string
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, _ ...any) Row {
	database.statement = statement
	return database.row
}

type fakeRow struct {
	values []any
	err    error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	for index, value := range row.values {
		switch destination := destinations[index].(type) {
		case *string:
			*destination = value.(string)
		case *bool:
			*destination = value.(bool)
		}
	}
	return nil
}
