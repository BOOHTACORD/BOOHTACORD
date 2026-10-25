package testscenario

import (
	"context"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
)

func AddText(t testing.TB, pool *pgxpool.Pool, mentions []string) string {
	t.Helper()
	id := uuid.NewString()
	if mentions == nil {
		mentions = []string{}
	}
	_, err := pool.Exec(context.Background(), `INSERT INTO messages(id,channel_id,author_id,client_message_id,body,mention_user_ids)VALUES($1,$2,$3,$4,'Synthetic',$5::uuid[])`, id, Channel, Author, uuid.NewString(), mentions)
	if err != nil {
		t.Fatal(err)
	}
	return id
}
func AddDirect(t testing.TB, pool *pgxpool.Pool, mentions []string) string {
	t.Helper()
	id := uuid.NewString()
	if mentions == nil {
		mentions = []string{}
	}
	_, err := pool.Exec(context.Background(), `INSERT INTO direct_message_messages(id,direct_message_id,author_id,client_message_id,body,mention_user_ids)VALUES($1,$2,$3,$4,'Synthetic',$5::uuid[])`, id, Direct, Author, uuid.NewString(), mentions)
	if err != nil {
		t.Fatal(err)
	}
	return id
}
