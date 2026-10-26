package preferencesaccess

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

const owner = "11111111-1111-4111-8111-111111111111"
const peer = "22222222-2222-4222-8222-222222222222"
const outsider = "33333333-3333-4333-8333-333333333333"
const pair = "44444444-4444-4444-8444-444444444444"
const channel = "55555555-5555-4555-8555-555555555555"

func fixturePool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	for i, id := range []string{owner, peer, outsider} {
		role := "MEMBER"
		if id == outsider {
			role = "ADMINISTRATOR"
		}
		if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,'Test','test',$3)`, id, "user"+string(rune('a'+i)), role); err != nil {
			t.Fatal(err)
		}
	}
	for _, sql := range []string{
		`INSERT INTO categories(id,name,position) VALUES('66666666-6666-4666-8666-666666666666','Test',0)`,
		`INSERT INTO channels(id,category_id,name,kind,position) VALUES('` + channel + `','66666666-6666-4666-8666-666666666666','Test','TEXT',0)`,
		`INSERT INTO direct_messages(id,participant_one_id,participant_two_id) VALUES('` + pair + `','` + owner + `','` + peer + `')`,
	} {
		if _, err := pool.Exec(ctx, sql); err != nil {
			t.Fatal(err)
		}
	}
	return pool
}
