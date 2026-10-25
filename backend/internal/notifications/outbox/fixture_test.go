package outbox

import (
	"context"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

const author = "11111111-1111-4111-8111-111111111111"
const recipient = "22222222-2222-4222-8222-222222222222"
const channel = "33333333-3333-4333-8333-333333333333"
const direct = "44444444-4444-4444-8444-444444444444"

func poolFor(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{author, recipient} {
		if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,'Synthetic','test','MEMBER')`, id, "user"+id[:4]); err != nil {
			t.Fatal(err)
		}
	}
	for _, query := range []string{
		`INSERT INTO categories(id,name,position) VALUES('55555555-5555-4555-8555-555555555555','Test',0)`,
		`INSERT INTO channels(id,category_id,name,kind,position) VALUES('` + channel + `','55555555-5555-4555-8555-555555555555','Test','TEXT',0)`,
		`INSERT INTO direct_messages(id,participant_one_id,participant_two_id) VALUES('` + direct + `','` + author + `','` + recipient + `')`,
		`UPDATE notification_runtime_policy SET operator_enabled=true`,
	} {
		if _, err := pool.Exec(ctx, query); err != nil {
			t.Fatal(err)
		}
	}
	return pool
}

const insertText = `INSERT INTO messages(id,channel_id,author_id,client_message_id,body) VALUES($1,$2,$3,$4,'synthetic') ON CONFLICT(author_id,channel_id,client_message_id) DO NOTHING`

func addText(t *testing.T, pool *pgxpool.Pool, client string) {
	t.Helper()
	if _, err := pool.Exec(context.Background(), insertText, uuid.NewString(), channel, author, client); err != nil {
		t.Fatal(err)
	}
}
