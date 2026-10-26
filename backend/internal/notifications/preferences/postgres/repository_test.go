package preferencespostgres

import (
	"context"
	"encoding/json"
	"errors"
	"reflect"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	preferences "voice-platform/backend/internal/notifications/preferences"
)

func equal(a, b any) bool {
	aJSON, _ := json.Marshal(a)
	bJSON, _ := json.Marshal(b)
	return reflect.DeepEqual(aJSON, bJSON)
}

func TestReadDecodesStoredDocumentAndReturnsDefaultWithoutRow(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{[]byte(`{"version":1,"revision":2,"enabled":true,"dm":{"mode":"none"},"text":{"mode":"mentions"},"overrides":[],"imported":false}`)}}}
	settings, err := New(database).Read(context.Background(), "account-1")
	if err != nil || settings.Revision != 2 || !settings.Enabled || settings.DM.Mode != preferences.ModeNone {
		t.Fatalf("Read() = %#v, %v", settings, err)
	}
	database.row = fakeRow{values: []any{[]byte(`{"version":1,"revision":0,"enabled":false,"dm":{"mode":"all"},"text":{"mode":"mentions"},"overrides":[],"imported":false}`)}}
	settings, err = New(database).Read(context.Background(), "account-2")
	if err != nil || !equal(settings, preferences.Default()) {
		t.Fatalf("Read(absent) = %#v, %v", settings, err)
	}
}

func TestSaveSendsCASArgumentsAndDecodesServerOwnedFields(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"account-1", 1, int64(3), true, []byte(`{"version":1,"revision":0,"enabled":false,"dm":{"mode":"all"},"text":{"mode":"mentions"},"overrides":[],"imported":false}`)}}}
	settings, err := New(database).Save(context.Background(), preferences.Input{AccountID: "account-1", ExpectedRevision: 2, Settings: preferences.Default(), Import: true})
	if err != nil || settings.Revision != 3 || !settings.Imported {
		t.Fatalf("Save() = %#v, %v", settings, err)
	}
	if database.arguments[0] != "account-1" || database.arguments[2] != int64(2) || database.arguments[3] != true {
		t.Fatalf("unexpected arguments: %#v", database.arguments)
	}
	document := string(database.arguments[1].([]byte))
	if !strings.Contains(document, `"mode":"mentions"`) {
		t.Fatalf("document does not carry settings: %s", document)
	}
}

func TestSaveMapsNoRowsToConflictOrAlreadyImported(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}
	if _, err := New(database).Save(context.Background(), preferences.Input{AccountID: "account-1", ExpectedRevision: 0}); !errors.Is(err, preferences.ErrConflict) {
		t.Fatalf("Save() error = %v, want ErrConflict", err)
	}
	database.row = fakeRow{err: pgx.ErrNoRows}
	if _, err := New(database).Save(context.Background(), preferences.Input{AccountID: "account-1", ExpectedRevision: 0, Import: true}); !errors.Is(err, preferences.ErrConflict) {
		t.Fatalf("Save(import without existing row) error = %v, want ErrConflict", err)
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
		case *int:
			*destination = value.(int)
		case *int64:
			*destination = value.(int64)
		case *bool:
			*destination = value.(bool)
		case *[]byte:
			*destination = value.([]byte)
		}
	}
	return nil
}

var _ = json.Marshal
