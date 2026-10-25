package outbox

import (
	"context"
	"github.com/google/uuid"
	"testing"
)

func TestRollbackAndClientReplayAreAtomic(t *testing.T) {
	ctx := context.Background()
	pool := poolFor(t)
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = tx.Exec(ctx, insertText, uuid.NewString(), channel, author, uuid.NewString()); err != nil {
		t.Fatal(err)
	}
	if err = tx.Rollback(ctx); err != nil {
		t.Fatal(err)
	}
	var intents, pending int
	if err = pool.QueryRow(ctx, `SELECT count(*) FROM notification_outbox`).Scan(&intents); err != nil || intents != 0 {
		t.Fatal(intents, err)
	}
	if err = pool.QueryRow(ctx, `SELECT intent_pending FROM notification_runtime_policy`).Scan(&pending); err != nil || pending != 0 {
		t.Fatal(pending, err)
	}
	client := uuid.NewString()
	addText(t, pool, client)
	addText(t, pool, client)
	if err = pool.QueryRow(ctx, `SELECT count(*) FROM notification_outbox`).Scan(&intents); err != nil || intents != 1 {
		t.Fatal("replay duplicated intent", intents, err)
	}
}
func TestQueueCapDoesNotRejectMessageCommit(t *testing.T) {
	ctx := context.Background()
	pool := poolFor(t)
	if _, err := pool.Exec(ctx, `UPDATE notification_runtime_policy SET max_intents=2`); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 5; i++ {
		addText(t, pool, uuid.NewString())
	}
	var messages, intents, pending, dropped int
	if err := pool.QueryRow(ctx, `SELECT (SELECT count(*) FROM messages),(SELECT count(*) FROM notification_outbox),intent_pending,dropped_intents FROM notification_runtime_policy`).Scan(&messages, &intents, &pending, &dropped); err != nil {
		t.Fatal(err)
	}
	if messages != 5 || intents != 2 || pending != 2 || dropped != 3 {
		t.Fatal(messages, intents, pending, dropped)
	}
}
func TestDirectMessageWithMentionCreatesOneMetadataIntent(t *testing.T) {
	ctx := context.Background()
	pool := poolFor(t)
	if _, err := pool.Exec(ctx, `INSERT INTO direct_message_messages(id,direct_message_id,author_id,client_message_id,body,mention_user_ids) VALUES($1,$2,$3,$4,'synthetic',$5::uuid[])`, uuid.NewString(), direct, author, uuid.NewString(), []string{recipient}); err != nil {
		t.Fatal(err)
	}
	var intents int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM notification_outbox WHERE kind='DM'`).Scan(&intents); err != nil || intents != 1 {
		t.Fatal(intents, err)
	}
	var privateColumns int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='notification_outbox' AND column_name IN('body','text','token','endpoint','attachments')`).Scan(&privateColumns); err != nil || privateColumns != 0 {
		t.Fatal("content copied into outbox", privateColumns, err)
	}
}
