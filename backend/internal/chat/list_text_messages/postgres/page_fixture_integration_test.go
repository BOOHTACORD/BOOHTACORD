package listtextmessagespostgres

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

func seedHistoryPage(t *testing.T, ctx context.Context, pool *pgxpool.Pool) string {
	t.Helper()
	const seed = `
INSERT INTO users(id,login,display_name,password_hash,role)
VALUES ('11111111-1111-4111-8111-111111111111','qa_history','History QA','fixture','MEMBER');
INSERT INTO categories(id,name,position)
VALUES ('22222222-2222-4222-8222-222222222222','History',0);
INSERT INTO channels(id,category_id,name,kind,position)
VALUES ('33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222','Text','TEXT',0),
       ('33333333-3333-4333-8333-333333333334','22222222-2222-4222-8222-222222222222','Other','TEXT',1);
INSERT INTO messages(id,channel_id,author_id,client_message_id,body,created_at,deleted_at)
SELECT gen_random_uuid(),'33333333-3333-4333-8333-333333333333',
       '11111111-1111-4111-8111-111111111111',gen_random_uuid(),
       CASE WHEN n % 17 = 0 THEN '' ELSE 'synthetic' END,
       timestamptz '2025-01-01 00:00:00+00' + n * interval '1 second',
       CASE WHEN n % 17 = 0 THEN now() ELSE NULL END
FROM generate_series(1,160) AS n;
INSERT INTO messages(id,channel_id,author_id,client_message_id,body,created_at)
VALUES ('77777777-7777-4777-8777-777777777771','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','88888888-8888-4888-8888-888888888881','tie one',timestamptz '2025-01-01 00:01:00+00'),
       ('77777777-7777-4777-8777-777777777772','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','88888888-8888-4888-8888-888888888882','tie two',timestamptz '2025-01-01 00:01:00+00'),
       ('77777777-7777-4777-8777-777777777773','33333333-3333-4333-8333-333333333334','11111111-1111-4111-8111-111111111111','88888888-8888-4888-8888-888888888883','other channel',now());
INSERT INTO attachments(id,owner_id,channel_id,original_name,storage_key,byte_size,state,attached_at,hidden_at)
VALUES ('44444444-4444-4444-8444-444444444441','11111111-1111-4111-8111-111111111111','33333333-3333-4333-8333-333333333333','first.txt','55555555-5555-4555-8555-555555555551',10,'ATTACHED',now(),NULL),
       ('44444444-4444-4444-8444-444444444442','11111111-1111-4111-8111-111111111111','33333333-3333-4333-8333-333333333333','second.txt','55555555-5555-4555-8555-555555555552',20,'ATTACHED',now(),NULL),
       ('44444444-4444-4444-8444-444444444443','11111111-1111-4111-8111-111111111111','33333333-3333-4333-8333-333333333333','hidden.txt','55555555-5555-4555-8555-555555555553',30,'HIDDEN',now(),now());
INSERT INTO message_attachments(message_id,attachment_id,position)
SELECT (SELECT id FROM messages WHERE channel_id='33333333-3333-4333-8333-333333333333' ORDER BY created_at DESC,id DESC LIMIT 1), id,
       CASE original_name WHEN 'first.txt' THEN 0 WHEN 'second.txt' THEN 1 ELSE 2 END
FROM attachments WHERE owner_id='11111111-1111-4111-8111-111111111111';
INSERT INTO attachments(id,owner_id,channel_id,original_name,storage_key,byte_size,state,attached_at)
VALUES ('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111','33333333-3333-4333-8333-333333333333','deleted.txt','55555555-5555-4555-8555-555555555554',40,'ATTACHED',now());
INSERT INTO message_attachments(message_id,attachment_id,position)
SELECT id,'44444444-4444-4444-8444-444444444444',0 FROM messages
WHERE channel_id='33333333-3333-4333-8333-333333333333' AND deleted_at IS NOT NULL
ORDER BY created_at DESC,id DESC LIMIT 1;`
	if _, err := pool.Exec(ctx, seed); err != nil {
		t.Fatal("seed disposable history:", err)
	}
	var anchor string
	if err := pool.QueryRow(ctx, `SELECT id::text FROM messages WHERE channel_id=$1 ORDER BY created_at DESC,id DESC OFFSET 50 LIMIT 1`, historyChannel).Scan(&anchor); err != nil {
		t.Fatal(err)
	}
	return anchor
}

func historyRows(t *testing.T, ctx context.Context, pool *pgxpool.Pool, query string, args ...any) [][]any {
	t.Helper()
	rows, err := pool.Query(ctx, query, args...)
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
