package migrate

import (
	"context"
	"github.com/google/uuid"
	"testing"
 contact "voice-platform/backend/internal/support/contact"
)

func TestProductSupportRequiresConsentAndNeverExportsHistory(t *testing.T) {
	db := newMigrationTestPool(t)
	ctx := context.Background()
	if err := Run(ctx, db); err != nil {
		t.Fatal(err)
	}
	actor := uuid.NewString()
	if _, err := db.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'support-test','Synthetic','test-only','MEMBER')`, actor); err != nil {
		t.Fatal(err)
	}
	var peer, mode string
	if err := db.QueryRow(ctx, `SELECT support_account_id::text,mode FROM support_contact_configuration`).Scan(&peer, &mode); err != nil || mode != "product" {
		t.Fatal("product support is not the default", err)
	}
 if status,err:=contact.New(db).Resolve(ctx,"");err!=nil||status.State!="available"||status.Mode!="product"{t.Fatal("owner status failed",err)}
 if _,err:=contact.New(db).Assign(ctx,peer);err==nil{t.Fatal("service peer accepted as a local human operator")}
	dm := uuid.NewString()
	if _, err := db.Exec(ctx, `INSERT INTO direct_messages(id,participant_one_id,participant_two_id) VALUES($1,LEAST($2::uuid,$3::uuid),GREATEST($2::uuid,$3::uuid))`, dm, actor, peer); err != nil {
		t.Fatal(err)
	}
	send := func(author string) error {
		_, err := db.Exec(ctx, `INSERT INTO direct_message_messages(id,direct_message_id,author_id,client_message_id,body) VALUES($1,$2,$3,$4,'Synthetic public request')`, uuid.NewString(), dm, author, uuid.NewString())
		return err
	}
	if send(actor) == nil {
		t.Fatal("publication without explicit consent accepted")
	}
	if _, err := db.Exec(ctx, `INSERT INTO support_public_consents(user_id,notice_version) VALUES($1,1)`, actor); err != nil {
		t.Fatal(err)
	}
	if err := send(actor); err != nil {
		t.Fatal(err)
	}
	if err := send(peer); err != nil {
		t.Fatal(err)
	}
	var count int
	if err := db.QueryRow(ctx, `SELECT count(*) FROM support_public_outbox`).Scan(&count); err != nil || count != 1 {
		t.Fatal("support reply was echoed or request was lost", err)
	}
	if _, err := db.Exec(ctx, `INSERT INTO sessions(token_digest,user_id,expires_at) VALUES($1,$2,now()+interval '1 hour')`, make([]byte, 32), peer); err == nil {
		t.Fatal("service peer acquired a human session")
	}
	if _, err := db.Exec(ctx, `UPDATE users SET password_hash='changed' WHERE id=$1`, peer); err == nil {
		t.Fatal("service account is mutable through human account administration")
	}
	if _, err := db.Exec(ctx, `UPDATE support_product_identity SET notice_version=2`); err != nil {
		t.Fatal(err)
	}
	if send(actor) == nil {
		t.Fatal("stale consent accepted")
	}
}

func TestExplicitLocalSupportSurvivesProductMigration(t *testing.T) {
	db := newMigrationTestPool(t)
	ctx := context.Background()
	applyMigrationPrefix(t, db, "0055")
	actor := uuid.NewString()
	if _, err := db.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'local-help','Synthetic','test-only','MEMBER');`, actor); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, `UPDATE support_contact_configuration SET support_account_id=$1,revision=2`, actor); err != nil {
		t.Fatal(err)
	}
	if err := Run(ctx, db); err != nil {
		t.Fatal(err)
	}
	var id, mode string
	if err := db.QueryRow(ctx, `SELECT support_account_id::text,mode FROM support_contact_configuration`).Scan(&id, &mode); err != nil || id != actor || mode != "local" {
		t.Fatal("explicit operator replaced", err)
	}
}
