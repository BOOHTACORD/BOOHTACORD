package supportbridge

import (
	"context"
	"encoding/json"
	"github.com/google/uuid"
	"net/http"
	"net/http/httptest"
	"testing"
	"voice-platform/backend/internal/database/migrate"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestWorkerOnlyExportsNewConsentedSupportAndImportsReplyExactlyOnce(t *testing.T) {
	ctx := context.Background()
	db := postgresfixture.New(t, ctx, "TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, db); err != nil {
		t.Fatal(err)
	}
	actor, other := uuid.NewString(), uuid.NewString()
	if _, err := db.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'bridge-one','Synthetic','test-only','MEMBER'),($2,'bridge-two','Synthetic','test-only','MEMBER')`, actor, other); err != nil {
		t.Fatal(err)
	}
	var peer string
	if err := db.QueryRow(ctx, `SELECT account_id::text FROM support_product_identity`).Scan(&peer); err != nil {
		t.Fatal(err)
	}
	supportDM, ordinary := uuid.NewString(), uuid.NewString()
	for _, pair := range [][3]string{{supportDM, actor, peer}, {ordinary, actor, other}} {
		if _, err := db.Exec(ctx, `INSERT INTO direct_messages(id,participant_one_id,participant_two_id) VALUES($1,LEAST($2::uuid,$3::uuid),GREATEST($2::uuid,$3::uuid))`, pair[0], pair[1], pair[2]); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := db.Exec(ctx, `INSERT INTO support_public_consents(user_id,notice_version) VALUES($1,1)`, actor); err != nil {
		t.Fatal(err)
	}
	for _, dm := range []string{supportDM, ordinary} {
		if _, err := db.Exec(ctx, `INSERT INTO direct_message_messages(id,direct_message_id,author_id,client_message_id,body) VALUES($1,$2,$3,$4,'Synthetic public test')`, uuid.NewString(), dm, actor, uuid.NewString()); err != nil {
			t.Fatal(err)
		}
	}
	exports := 0
	conversation := ""
	invalid := false
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/support/v1/status":
			json.NewEncoder(w).Encode(map[string]any{"notice_version": 1, "public": true, "repository": "Egkurilov/BOOHTACORD"})
		case "/support/v1/messages":
			var payload publication
			if json.NewDecoder(r.Body).Decode(&payload) != nil {
				invalid = true
			}
			exports++
			conversation = payload.Conversation
			if payload.Body != "Synthetic public test" || payload.Consent != 1 || conversation == supportDM || payload.Operation == "" {
				invalid = true
			}
			w.WriteHeader(202)
		case "/support/v1/replies":
			if r.URL.Query().Get("after") == "0" {
				json.NewEncoder(w).Encode(map[string]any{"replies": []any{map[string]any{"id": 101, "conversation": conversation, "body": "Synthetic operator reply"}}})
			} else {
				w.Write([]byte(`{"replies":[]}`))
			}
		default:
			invalid = true
			w.WriteHeader(404)
		}
	}))
	defer server.Close()
	worker, err := NewWorker(ctx, db, t.TempDir(), server.URL+"/support/v1", eventhub.New(64))
	if err != nil {
		t.Fatal(err)
	}
	if err = worker.Tick(ctx); err != nil {
		t.Fatal("first bridge tick failed", err)
	}
	if err = worker.Tick(ctx); err != nil {
		t.Fatal("replayed bridge tick failed", err)
	}
	var replies, pending int
	if err = db.QueryRow(ctx, `SELECT count(*) FROM direct_message_messages WHERE author_id=$1 AND direct_message_id=$2`, peer, supportDM).Scan(&replies); err != nil {
		t.Fatal(err)
	}
	if err = db.QueryRow(ctx, `SELECT count(*) FROM support_public_outbox WHERE delivered_at IS NULL`).Scan(&pending); err != nil {
		t.Fatal(err)
	}
	if invalid || exports != 1 || replies != 1 || pending != 0 {
		t.Fatalf("unsafe bridge result exports=%d replies=%d pending=%d", exports, replies, pending)
	}
}
