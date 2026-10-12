package rolepolicypostgres

import (
	"encoding/json"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
	rolepolicy "voice-platform/backend/internal/authorization/role_policy"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestMemberPolicyRealPostgresCommitsRevisionAndAuditAtomically(t *testing.T) {
	f := guildfixture.New(t)
	repository := New(NewPoolDatabase(f.Pool))
	before, err := repository.LoadMember(f.Context)
	if err != nil {
		t.Fatal("initial policy unavailable")
	}
	policy := before
	policy.TextDelete = !before.TextDelete
	after, err := repository.UpdateMember(f.Context, rolepolicy.UpdateCommand{ActorID: f.Admin, ExpectedRevision: before.Revision, Policy: policy, ConfirmDeleteGrants: true})
	if err != nil {
		var pgError *pgconn.PgError
		if errors.As(err, &pgError) {
			t.Fatalf("policy update failed: sqlstate=%s", pgError.Code)
		}
		t.Fatalf("policy update failed: type=%T", err)
	}
	if after.Revision != before.Revision+1 || after.TextDelete != policy.TextDelete {
		t.Fatal("returned policy/revision mismatch")
	}
	stored, err := repository.LoadMember(f.Context)
	if err != nil || stored != after {
		t.Fatal("updated policy was not committed")
	}
	var metadata []byte
	if err = f.Pool.QueryRow(f.Context, `SELECT metadata FROM audit_events WHERE event_type='MEMBER_PERMISSIONS_UPDATED'`).Scan(&metadata); err != nil {
		t.Fatal("audit event unavailable")
	}
	var audit struct {
		Before   map[string]bool `json:"before"`
		After    map[string]bool `json:"after"`
		Revision int64           `json:"revision"`
	}
	if json.Unmarshal(metadata, &audit) != nil || audit.Revision != after.Revision || audit.Before["channel.text.delete"] != before.TextDelete || audit.After["channel.text.delete"] != after.TextDelete {
		t.Fatal("audit does not match committed change")
	}
	_, err = repository.UpdateMember(f.Context, rolepolicy.UpdateCommand{ActorID: f.Admin, ExpectedRevision: before.Revision, Policy: before, ConfirmDeleteGrants: true})
	if !errors.Is(err, rolepolicy.ErrRevisionConflict) {
		t.Fatal("stale policy write was not rejected")
	}
	var count int
	if err = f.Pool.QueryRow(f.Context, `SELECT count(*) FROM audit_events WHERE event_type='MEMBER_PERMISSIONS_UPDATED'`).Scan(&count); err != nil || count != 1 {
		t.Fatal("stale write changed audit")
	}
}
