package setvoicedeafenpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	setvoicedeafen "voice-platform/backend/internal/media/set_voice_deafen"
)

type testRow struct {
	value string
	err   error
}

func (row testRow) Scan(dest ...any) error {
	if row.err != nil {
		return row.err
	}
	*dest[0].(*string) = row.value
	return nil
}

type testTx struct {
	row       testRow
	committed bool
}

func (tx *testTx) QueryRow(_ context.Context, query string, _ ...any) Row {
	for _, fragment := range []string{"lease.id=$1::uuid", "lease.user_id=$2::uuid", "lease.session_token_digest=$3", "lease.revoked_at IS NULL", "session.user_id=lease.user_id", "session.revoked_at IS NULL", "session.expires_at>clock_timestamp()", "session.last_active_at>", "FOR UPDATE OF lease, session"} {
		if !strings.Contains(query, fragment) {
			panic("missing lease authorization predicate: " + fragment)
		}
	}
	return tx.row
}
func (tx *testTx) Commit(context.Context) error   { tx.committed = true; return nil }
func (tx *testTx) Rollback(context.Context) error { return nil }

type testDB struct{ tx *testTx }

func (db testDB) Begin(context.Context) (Transaction, error) { return db.tx, nil }

type testPublisher struct {
	lease, channel string
	deafened       bool
	calls          int
}

func (p *testPublisher) Publish(_ context.Context, lease, channel string, deafened bool) error {
	p.lease, p.channel, p.deafened, p.calls = lease, channel, deafened, p.calls+1
	return nil
}

func TestApplyPublishesOnlyAfterExactActiveLeaseLookup(t *testing.T) {
	tx := &testTx{row: testRow{value: "22222222-2222-4222-8222-222222222222"}}
	publisher := &testPublisher{}
	repository := New(testDB{tx}, publisher)
	err := repository.Apply(context.Background(), setvoicedeafen.Principal{AccountID: "33333333-3333-4333-8333-333333333333"}, "11111111-1111-4111-8111-111111111111", true)
	if err != nil || !tx.committed || publisher.calls != 1 || publisher.lease != "11111111-1111-4111-8111-111111111111" || publisher.channel != "22222222-2222-4222-8222-222222222222" || !publisher.deafened {
		t.Fatalf("committed=%v publisher=%+v err=%v", tx.committed, publisher, err)
	}
}

func TestApplyDoesNotPublishUnavailableLease(t *testing.T) {
	publisher := &testPublisher{}
	repository := New(testDB{&testTx{row: testRow{err: pgx.ErrNoRows}}}, publisher)
	err := repository.Apply(context.Background(), setvoicedeafen.Principal{AccountID: "33333333-3333-4333-8333-333333333333"}, "11111111-1111-4111-8111-111111111111", true)
	if !errors.Is(err, setvoicedeafen.ErrDenied) || publisher.calls != 0 {
		t.Fatalf("publisher=%+v err=%v", publisher, err)
	}
}
