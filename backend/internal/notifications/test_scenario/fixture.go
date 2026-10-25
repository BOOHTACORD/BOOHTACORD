// Package testscenario owns synthetic notification fixtures, never runtime data.
package testscenario

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

const Author = "11111111-1111-4111-8111-111111111111"
const Recipient = "22222222-2222-4222-8222-222222222222"
const Outsider = "33333333-3333-4333-8333-333333333333"
const Channel = "44444444-4444-4444-8444-444444444444"
const Direct = "55555555-5555-4555-8555-555555555555"
const Category = "66666666-6666-4666-8666-666666666666"

func New(t testing.TB) *pgxpool.Pool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	for i, id := range []string{Author, Recipient, Outsider} {
		role := "MEMBER"
		if id == Outsider {
			role = "ADMINISTRATOR"
		}
		if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,'Synthetic','test',$3)`, id, "notify"+string(rune('a'+i)), role); err != nil {
			t.Fatal(err)
		}
		digest := [32]byte{byte(i + 1)}
		if _, err := pool.Exec(ctx, `INSERT INTO sessions(token_digest,user_id)VALUES($1,$2)`, digest[:], id); err != nil {
			t.Fatal(err)
		}
	}
	for _, sql := range []string{
		`INSERT INTO categories(id,name,position)VALUES('` + Category + `','Synthetic',0)`,
		`INSERT INTO channels(id,category_id,name,kind,position)VALUES('` + Channel + `','` + Category + `','Synthetic','TEXT',0)`,
		`INSERT INTO direct_messages(id,participant_one_id,participant_two_id)VALUES('` + Direct + `','` + Author + `','` + Recipient + `')`,
	} {
		if _, err := pool.Exec(ctx, sql); err != nil {
			t.Fatal(err)
		}
	}
	return pool
}
