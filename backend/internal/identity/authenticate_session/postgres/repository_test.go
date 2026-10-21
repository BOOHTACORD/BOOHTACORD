package sessionpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
)

func TestRepositoryLoadsOnlyActiveUnblockedPrincipal(t *testing.T) {
	expiresAt := time.Now().Add(24 * time.Hour)
	database := &fakeDatabase{row: fakeRow{values: []any{"account-1", "MEMBER", "Аня [QA]", expiresAt}}}
	repository := New(database)
	digest := sha256.Sum256([]byte("opaque session"))

	principal, err := repository.FindActive(context.Background(), digest)
	if err != nil {
		t.Fatalf("FindActive() error = %v", err)
	}
	storedDigest, ok := database.arguments[0].([]byte)
	if principal != (authenticatesession.Principal{AccountID: "account-1", Role: "MEMBER", DisplayName: "Аня [QA]", ExpiresAt: expiresAt}) || !ok || len(storedDigest) != sha256.Size || database.arguments[1] != int64(session.IdleLifetime.Seconds()) || !strings.Contains(database.statement, "s.revoked_at IS NULL") || !strings.Contains(database.statement, "u.blocked_at IS NULL") || !strings.Contains(database.statement, "u.display_name") || !strings.Contains(database.statement, "s.expires_at > now()") || !strings.Contains(database.statement, "s.last_active_at > now() - ($2::double precision * interval '1 second')") {
		t.Fatalf("principal = %#v, statement = %s, arguments = %#v", principal, database.statement, database.arguments)
	}
}

func TestRepositoryMapsMissingActiveSession(t *testing.T) {
	repository := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}})
	_, err := repository.FindActive(context.Background(), sha256.Sum256([]byte("missing")))
	if !errors.Is(err, authenticatesession.ErrSessionNotFound) {
		t.Fatalf("FindActive() error = %v", err)
	}
}

type fakeDatabase struct {
	row       fakeRow
	statement string
	arguments []any
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	database.statement = statement
	database.arguments = arguments
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
		case *time.Time:
			*destination = value.(time.Time)
		default:
			return errors.New("unexpected scan destination")
		}
	}
	return nil
}
