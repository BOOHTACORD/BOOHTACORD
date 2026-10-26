package authorizedirectmessageattachmentpostgres

import (
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

type attachmentFixture struct{ pool *pgxpool.Pool }

const participantOne = "11111111-1111-4111-8111-111111111111"
const participantTwo = "22222222-2222-4222-8222-222222222222"
const outsider = "33333333-3333-4333-8333-333333333333"
const administrator = "44444444-4444-4444-8444-444444444444"
const pair = "55555555-5555-4555-8555-555555555555"

func newAttachmentFixture(t *testing.T) attachmentFixture {
	t.Helper()
	pool := fixture.New(t, t.Context(), "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(t.Context(), pool); err != nil {
		t.Fatal(err)
	}
	f := attachmentFixture{pool}
	f.exec(t, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES
		($1,'first','First','test-only','MEMBER'),($2,'second','Second','test-only','MEMBER'),
		($3,'outsider','Outsider','test-only','MEMBER'),($4,'admin','Admin','test-only','ADMINISTRATOR')`, participantOne, participantTwo, outsider, administrator)
	f.exec(t, "INSERT INTO direct_messages(id,participant_one_id,participant_two_id) VALUES($1,$2,$3)", pair, participantOne, participantTwo)
	return f
}

func (f attachmentFixture) exec(t *testing.T, query string, args ...any) {
	t.Helper()
	if _, err := f.pool.Exec(t.Context(), query, args...); err != nil {
		t.Fatal(err)
	}
}

func (f attachmentFixture) snapshot(t *testing.T) string {
	t.Helper()
	var state string
	if err := f.pool.QueryRow(t.Context(), `SELECT jsonb_build_object(
		'users',(SELECT jsonb_agg(to_jsonb(u) ORDER BY id) FROM users u),
		'pairs',(SELECT jsonb_agg(to_jsonb(d) ORDER BY id) FROM direct_messages d))::text`).Scan(&state); err != nil {
		t.Fatal(err)
	}
	return state
}
