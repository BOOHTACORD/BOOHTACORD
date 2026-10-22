package supportbridge

import (
	"context"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"os"
	"path/filepath"
	"testing"
)

func seedPublicFile(t *testing.T, db *pgxpool.Pool, actor, supportDM, messageID string) (string, []byte) {
	t.Helper()
	ctx := context.Background()
	root := t.TempDir()
	directory := filepath.Join(root, "unattached")
	if err := os.Mkdir(directory, 0700); err != nil {
		t.Fatal(err)
	}
	key, attachment := uuid.NewString(), uuid.NewString()
	fixture := []byte("Synthetic file fixture")
	if err := os.WriteFile(filepath.Join(directory, key), fixture, 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, `INSERT INTO attachments(id,owner_id,direct_message_id,original_name,storage_key,byte_size,state,attached_at) VALUES($1,$2,$3,'synthetic.txt',$4,$5,'ATTACHED',now())`, attachment, actor, supportDM, key, len(fixture)); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, `INSERT INTO direct_message_attachments(message_id,attachment_id,position) VALUES($1,$2,0)`, messageID, attachment); err != nil {
		t.Fatal(err)
	}
	return root, fixture
}
