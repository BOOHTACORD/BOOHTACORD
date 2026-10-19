package postgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	presence "voice-platform/backend/internal/media/screen_viewer_presence"
)

type testRow struct {
	values []string
	err    error
}

func (row testRow) Scan(dest ...any) error {
	if row.err != nil {
		return row.err
	}
	if len(dest) != len(row.values) {
		return errors.New("unexpected scan arity")
	}
	for index := range dest {
		*dest[index].(*string) = row.values[index]
	}
	return nil
}

type testDatabase struct {
	query string
	args  []any
	row   testRow
}

func (database *testDatabase) QueryRow(_ context.Context, query string, args ...any) Row {
	database.query, database.args = query, args
	return database.row
}

func TestOwnerAuthorizationBindsAccountSessionAndOpenLease(t *testing.T) {
	database := &testDatabase{row: testRow{values: []string{"channel", "owner-account"}}}
	authority := New(database)
	principal := presence.Principal{AccountID: "owner-account", SessionDigest: [32]byte{1, 2}}
	channel, owner, err := authority.AuthorizeOwner(context.Background(), principal, "owner-lease")
	if err != nil || channel != "channel" || owner != "owner-account" {
		t.Fatalf("channel=%q owner=%q err=%v", channel, owner, err)
	}
	for _, clause := range []string{"owner.user_id = $2", "owner.session_token_digest = $3", "owner.revoked_at IS NULL", "owner_session.revoked_at IS NULL", "channel.admission_closed_at IS NULL"} {
		if !strings.Contains(database.query, clause) {
			t.Fatalf("owner ACL omitted %q", clause)
		}
	}
	if len(database.args) != 3 || database.args[0] != "owner-lease" || database.args[1] != "owner-account" {
		t.Fatalf("args=%#v", database.args)
	}
}

func TestViewerAuthorizationRequiresBothActiveLeasesInOneChannel(t *testing.T) {
	database := &testDatabase{row: testRow{values: []string{"channel", "owner-account", "viewer-account"}}}
	authority := New(database)
	principal := presence.Principal{AccountID: "viewer-account", SessionDigest: [32]byte{9}}
	channel, owner, viewer, err := authority.AuthorizeViewer(context.Background(), principal, "viewer-lease", "owner-lease")
	if err != nil || channel != "channel" || owner != "owner-account" || viewer != "viewer-account" {
		t.Fatalf("channel=%q owner=%q viewer=%q err=%v", channel, owner, viewer, err)
	}
	for _, clause := range []string{"viewer.channel_id = owner.channel_id", "viewer.id = $1", "owner.id = $2", "viewer.user_id = $3", "viewer.session_token_digest = $4", "viewer.revoked_at IS NULL", "viewer_session.revoked_at IS NULL", "owner.revoked_at IS NULL", "owner_session.revoked_at IS NULL", "viewer_account.blocked_at IS NULL", "owner_account.blocked_at IS NULL", "channel.kind = 'VOICE'", "channel.archived_at IS NULL", "channel.admission_closed_at IS NULL"} {
		if !strings.Contains(database.query, clause) {
			t.Fatalf("viewer ACL omitted %q", clause)
		}
	}
	if len(database.args) != 4 || database.args[0] != "viewer-lease" || database.args[1] != "owner-lease" || database.args[2] != "viewer-account" {
		t.Fatalf("args=%#v", database.args)
	}
}

func TestInactiveCrossChannelOrBlockedLeaseDoesNotAuthorize(t *testing.T) {
	database := &testDatabase{row: testRow{err: pgx.ErrNoRows}}
	_, _, _, err := New(database).AuthorizeViewer(context.Background(), presence.Principal{AccountID: "outsider"}, "viewer-lease", "owner-lease")
	if !errors.Is(err, presence.ErrDenied) {
		t.Fatalf("authorization error=%v", err)
	}
}
