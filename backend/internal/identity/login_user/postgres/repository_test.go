package loginpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/login_user"
)

func TestRepositoryLoadsLoginAccountWithBoundLogin(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"account-1", "egor", "$argon2id$hash", false}}}
	repository := New(database)

	account, err := repository.FindByLogin(context.Background(), "egor")
	if err != nil {
		t.Fatalf("FindByLogin() error = %v", err)
	}
	if account.ID != "account-1" || account.PasswordHash != "$argon2id$hash" || database.arguments[0] != "egor" || strings.Contains(database.statement, "egor") {
		t.Fatalf("account = %#v, statement = %s, arguments = %#v", account, database.statement, database.arguments)
	}
}

func TestRepositoryMapsMissingAccount(t *testing.T) {
	repository := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}})
	_, err := repository.FindByLogin(context.Background(), "egor")
	if !errors.Is(err, loginuser.ErrAccountNotFound) {
		t.Fatalf("FindByLogin() error = %v, want ErrAccountNotFound", err)
	}
}

func TestRepositoryStoresOnlySessionDigest(t *testing.T) {
	database := &fakeDatabase{}
	repository := New(database)
	digest := sha256.Sum256([]byte("opaque session"))
	expiresAt := time.Now().Add(24 * time.Hour)

	if err := repository.Create(context.Background(), "account-1", digest, expiresAt); err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	storedDigest, ok := database.arguments[0].([]byte)
	if !ok || len(storedDigest) != sha256.Size || database.arguments[1] != "account-1" || database.arguments[2] != expiresAt || strings.Contains(database.statement, "opaque session") || !strings.Contains(database.statement, "expires_at") {
		t.Fatalf("statement = %s, arguments = %#v", database.statement, database.arguments)
	}
}

type fakeDatabase struct {
	row       fakeRow
	statement string
	arguments []any
	err       error
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	database.statement = statement
	database.arguments = arguments
	return database.row
}

func (database *fakeDatabase) Exec(_ context.Context, statement string, arguments ...any) error {
	database.statement = statement
	database.arguments = arguments
	return database.err
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
