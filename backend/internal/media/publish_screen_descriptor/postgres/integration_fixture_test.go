package publishscreendescriptorpostgres

import (
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

type descriptorFixture struct{ pool *pgxpool.Pool }

func newDescriptorFixture(t *testing.T) descriptorFixture {
	t.Helper()
	pool := fixture.New(t, t.Context(), "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(t.Context(), pool); err != nil {
		t.Fatal(err)
	}
	f := descriptorFixture{pool}
	f.exec(t, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES
		($1,'publisher','Publisher','test-only','MEMBER'),($2,'other','Other','test-only','MEMBER')`, testAccount, foreignAccount)
	f.exec(t, "INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)", make([]byte, 32), testAccount)
	category := uuid.NewString()
	f.exec(t, "INSERT INTO categories(id,name,position) VALUES($1,'Media',0)", category)
	f.exec(t, "INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$2,'Voice','VOICE',0)", testChannel, category)
	f.exec(t, "INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest) VALUES($1,$2,$3,$4)", testLease, testAccount, testChannel, make([]byte, 32))
	return f
}

func (f descriptorFixture) exec(t *testing.T, query string, args ...any) {
	t.Helper()
	if _, err := f.pool.Exec(t.Context(), query, args...); err != nil {
		t.Fatal(err)
	}
}

func (f descriptorFixture) snapshot(t *testing.T) string {
	t.Helper()
	var state string
	if err := f.pool.QueryRow(t.Context(), "SELECT row_to_json(l)::text FROM voice_leases l WHERE id=$1", testLease).Scan(&state); err != nil {
		t.Fatal(err)
	}
	return state
}
