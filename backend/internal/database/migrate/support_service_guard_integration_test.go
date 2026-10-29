package migrate

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

func ordinaryGuardUser(t *testing.T, db *pgxpool.Pool) string {
	t.Helper()
	id := uuid.NewString()
	_, err := db.Exec(context.Background(), `INSERT INTO users(id,login,display_name,password_hash,role)
	 VALUES($1,$2,'Synthetic','test-only','MEMBER')`, id, "guard-"+id[:24])
	if err != nil {
		t.Fatal(err)
	}
	return id
}

func requireOrdinaryDelete(t *testing.T, db *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()
	id := ordinaryGuardUser(t, db)
	tag, err := db.Exec(ctx, `UPDATE users SET display_name='Updated' WHERE id=$1`, id)
	if err != nil || tag.RowsAffected() != 1 {
		t.Fatalf("ordinary UPDATE rows=%d error=%v", tag.RowsAffected(), err)
	}
	tag, err = db.Exec(ctx, `DELETE FROM users WHERE id=$1`, id)
	if err != nil || tag.RowsAffected() != 1 {
		t.Fatalf("ordinary DELETE rows=%d error=%v", tag.RowsAffected(), err)
	}
	var remains bool
	if err := db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE id=$1)`, id).Scan(&remains); err != nil || remains {
		t.Fatalf("ordinary user remains=%v error=%v", remains, err)
	}
}

func TestSupportServiceGuardAllowsOrdinaryDelete(t *testing.T) {
	db := newMigrationTestPool(t)
	if err := Run(context.Background(), db); err != nil {
		t.Fatal(err)
	}
	requireOrdinaryDelete(t, db)
}

func TestSupportServiceGuardUpgradeAndRepeatedStartup(t *testing.T) {
	db := newMigrationTestPool(t)
	applyMigrationPrefix(t, db, "0064")
	var before, after string
	if err := db.QueryRow(context.Background(), `SELECT md5(row(i.*)::text) FROM support_product_identity i`).Scan(&before); err != nil {
		t.Fatal(err)
	}
	for pass := 0; pass < 2; pass++ {
		if err := Run(context.Background(), db); err != nil {
			t.Fatal(err)
		}
		requireOrdinaryDelete(t, db)
	}
	if err := db.QueryRow(context.Background(), `SELECT md5(row(i.*)::text) FROM support_product_identity i`).Scan(&after); err != nil || before != after {
		t.Fatalf("support identity changed on startup: %v", err)
	}
}

func TestSupportServiceGuardRetainsIdentityAndSessionFences(t *testing.T) {
	db := newMigrationTestPool(t)
	ctx := context.Background()
	if err := Run(ctx, db); err != nil {
		t.Fatal(err)
	}
	var peer, before, after string
	if err := db.QueryRow(ctx, `SELECT u.id,md5(row(u.*)::text) FROM users u JOIN support_product_identity i ON i.account_id=u.id`).Scan(&peer, &before); err != nil {
		t.Fatal(err)
	}
	for _, statement := range []string{
		`DELETE FROM users WHERE id=$1`,
		`UPDATE users SET display_name='Changed' WHERE id=$1`,
		`INSERT INTO sessions(token_digest,user_id,expires_at) VALUES(decode(repeat('00',32),'hex'),$1,now()+interval '1 hour')`,
	} {
		_, err := db.Exec(ctx, statement, peer)
		var denied *pgconn.PgError
		if !errors.As(err, &denied) || denied.Code != "42501" {
			t.Fatalf("support guard must reject with42501, got %v", err)
		}
	}
	actor := ordinaryGuardUser(t, db)
	if _, err := db.Exec(ctx, `INSERT INTO sessions(token_digest,user_id,expires_at) VALUES(decode(repeat('01',32),'hex'),$1,now()+interval '1 hour')`, actor); err != nil {
		t.Fatal(err)
	}
	_, err := db.Exec(ctx, `UPDATE sessions SET user_id=$1 WHERE token_digest=decode(repeat('01',32),'hex')`, peer)
	var denied *pgconn.PgError
	if !errors.As(err, &denied) || denied.Code != "42501" {
		t.Fatalf("support session update must reject with42501, got %v", err)
	}
	if err := db.QueryRow(ctx, `SELECT md5(row(u.*)::text) FROM users u WHERE id=$1`, peer).Scan(&after); err != nil || before != after {
		t.Fatalf("protected user changed: %v", err)
	}
}
