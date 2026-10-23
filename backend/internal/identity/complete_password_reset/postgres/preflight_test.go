package resetpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	reset "voice-platform/backend/internal/identity/complete_password_reset"
)

type preflightDatabase struct {
	ctx       context.Context
	statement string
	args      []any
	err       error
	calls     int
	at        time.Time
}

func (db *preflightDatabase) QueryRow(ctx context.Context, sql string, args ...any) Row {
	db.calls++
	db.at = time.Now()
	db.ctx = ctx
	db.statement = sql
	db.args = args
	return preflightRow{db.err}
}

type preflightRow struct{ err error }

func (row preflightRow) Scan(dest ...any) error {
	if row.err != nil {
		return row.err
	}
	*dest[0].(*int) = 1
	return nil
}

func TestPreflightIsBoundedReadOnlyAndBindsOnlyDigest(t *testing.T) {
	db := &preflightDatabase{}
	digest := sha256.Sum256([]byte("synthetic capability"))
	before := time.Now()
	if err := New(db).Preflight(context.Background(), digest); err != nil {
		t.Fatal(err)
	}
	deadline, ok := db.ctx.Deadline()
	if !ok || deadline.After(db.at.Add(2*time.Second)) || !deadline.After(before) {
		t.Fatal("preflight query has no bounded deadline")
	}
	if len(db.args) != 1 {
		t.Fatal("preflight must only bind digest")
	}
	bound, ok := db.args[0].([]byte)
	if !ok || string(bound) != string(digest[:]) {
		t.Fatal("digest was not bound")
	}
	for _, fragment := range []string{"SELECT 1", "token_digest = $1", "used_at IS NULL", "expires_at > now()"} {
		if !strings.Contains(db.statement, fragment) {
			t.Fatal("missing eligibility predicate")
		}
	}
	for _, forbidden := range []string{"UPDATE", "INSERT", "DELETE", "FOR UPDATE", "BEGIN"} {
		if strings.Contains(db.statement, forbidden) {
			t.Fatal("preflight must not lock or mutate")
		}
	}
}
func TestPreflightPreservesEarlierDeadlineAndFailsClosed(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	db := &preflightDatabase{err: pgx.ErrNoRows}
	err := New(db).Preflight(ctx, [sha256.Size]byte{})
	if !errors.Is(err, reset.ErrResetNotFound) {
		t.Fatal("missing token must remain generic rejection")
	}
	parent, _ := ctx.Deadline()
	child, _ := db.ctx.Deadline()
	if !child.Equal(parent) {
		t.Fatal("preflight extended parent deadline")
	}
	failure := errors.New("synthetic database failure")
	db.err = failure
	if err := New(db).Preflight(context.Background(), [sha256.Size]byte{}); !errors.Is(err, failure) || errors.Is(err, reset.ErrResetNotFound) {
		t.Fatal("infrastructure failure must not authorize reset or become invalid credentials")
	}
}
func TestPreflightCancelledContextDoesNotQuery(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	db := &preflightDatabase{}
	if err := New(db).Preflight(ctx, [sha256.Size]byte{}); !errors.Is(err, context.Canceled) || db.calls != 0 {
		t.Fatal("cancelled request reached database")
	}
}
