package edittextmessagepostgres

import (
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

type editFixture struct {
	pool                                      *pgxpool.Pool
	author, outsider, channel, other, message string
}

func newEditFixture(t *testing.T) editFixture {
	t.Helper()
	ctx := t.Context()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	f := editFixture{pool, uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString()}
	f.exec(t, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES
		($1,'author','Author','test-only','MEMBER'),($2,'outsider','Outsider','test-only','ADMINISTRATOR')`, f.author, f.outsider)
	category := uuid.NewString()
	f.exec(t, `INSERT INTO categories(id,name,position) VALUES($1,'Edit',0)`, category)
	f.exec(t, `INSERT INTO channels(id,category_id,name,kind,position) VALUES
		($1,$3,'Text','TEXT',0),($2,$3,'Other','TEXT',1)`, f.channel, f.other, category)
	f.exec(t, `INSERT INTO messages(id,channel_id,author_id,client_message_id,body)
		VALUES($1,$2,$3,$4,'original')`, f.message, f.channel, f.author, uuid.NewString())
	return f
}

func (f editFixture) exec(t *testing.T, query string, args ...any) {
	t.Helper()
	if _, err := f.pool.Exec(t.Context(), query, args...); err != nil {
		t.Fatal(err)
	}
}

func (f editFixture) snapshot(t *testing.T) string {
	t.Helper()
	var state string
	if err := f.pool.QueryRow(t.Context(), `SELECT row_to_json(m)::text FROM messages m WHERE id=$1`, f.message).Scan(&state); err != nil {
		t.Fatal(err)
	}
	return state
}
