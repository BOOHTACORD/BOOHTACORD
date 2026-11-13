package listtopologypostgres

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

const topologyActor = "11111111-1111-4111-8111-111111111111"
const topologyAuthor = "11111111-1111-4111-8111-111111111112"
const topologyFirstUnread = "44444444-4444-4444-8444-000000000002"

func seedTopologyUnread(t *testing.T, ctx context.Context, pool *pgxpool.Pool) {
	t.Helper()
	const seed = `
INSERT INTO users(id,login,display_name,password_hash,role) VALUES
 ('11111111-1111-4111-8111-111111111111','top_actor','Actor','fixture','MEMBER'),
 ('11111111-1111-4111-8111-111111111112','top_author','Author','fixture','MEMBER');
INSERT INTO categories(id,name,position) VALUES
 ('22222222-2222-4222-8222-222222222221','Visible',0),
 ('22222222-2222-4222-8222-222222222222','Empty',1);
INSERT INTO channels(id,category_id,name,kind,position) VALUES
 ('33333333-3333-4333-8333-333333333331','22222222-2222-4222-8222-222222222221','Text','TEXT',0),
 ('33333333-3333-4333-8333-333333333332','22222222-2222-4222-8222-222222222221','Voice','VOICE',1);
INSERT INTO messages(id,channel_id,author_id,client_message_id,body,created_at,deleted_at,mention_user_ids)
SELECT ('44444444-4444-4444-8444-' || lpad(n::text,12,'0'))::uuid,
 '33333333-3333-4333-8333-333333333331',
 CASE WHEN n=5 THEN '11111111-1111-4111-8111-111111111111'::uuid ELSE '11111111-1111-4111-8111-111111111112'::uuid END,
 gen_random_uuid(), CASE WHEN n=6 THEN '' ELSE 'synthetic' END,
 timestamptz '2025-01-01 00:00:00+00' + n * interval '1 second',
 CASE WHEN n=6 THEN now() ELSE NULL END,
 CASE WHEN n IN (2,4) THEN ARRAY['11111111-1111-4111-8111-111111111111'::uuid] ELSE ARRAY[]::uuid[] END
FROM generate_series(1,6) n;
INSERT INTO channel_read_cursors(account_id,channel_id,message_id,message_created_at)
SELECT '11111111-1111-4111-8111-111111111111',channel_id,id,created_at FROM messages
WHERE id='44444444-4444-4444-8444-000000000001';`
	if _, err := pool.Exec(ctx, seed); err != nil {
		t.Fatal("seed disposable topology:", err)
	}
}

func topologyRows(t *testing.T, ctx context.Context, pool *pgxpool.Pool, query, actor string) [][]any {
	t.Helper()
	rows, err := pool.Query(ctx, query, actor)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	var result [][]any
	for rows.Next() {
		values, err := rows.Values()
		if err != nil {
			t.Fatal(err)
		}
		result = append(result, values)
	}
	if err := rows.Err(); err != nil {
		t.Fatal(err)
	}
	return result
}
