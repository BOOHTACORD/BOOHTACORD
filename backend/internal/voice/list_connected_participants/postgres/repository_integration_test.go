package listconnectedparticipantspostgres

import (
	"context"
	"crypto/sha256"
	"testing"

	"github.com/google/uuid"
)

func TestPostgresRosterExcludesRevokedBlockedAndArchivedState(t *testing.T) {
	pool := newRosterFixture(t)
	ctx := context.Background()
	actor, member, category, voice, text, lease := uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString()
	digest := sha256.Sum256([]byte("roster-member-session"))
	for _, user := range []struct{ id, login string }{{actor, "roster_actor"}, {member, "roster_member"}} {
		if _, err := pool.Exec(ctx, `INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1,$2,$3,'test','MEMBER')`, user.id, user.login, user.login); err != nil {
			t.Fatal(err)
		}
	}
	for _, statement := range []struct {
		query string
		args  []any
	}{
		{`INSERT INTO sessions (token_digest, user_id) VALUES ($1,$2)`, []any{digest[:], member}},
		{`INSERT INTO categories (id, name, position) VALUES ($1,'Category',0)`, []any{category}},
		{`INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1,$2,'Voice','VOICE',0)`, []any{voice, category}},
		{`INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1,$2,'Text','TEXT',1)`, []any{text, category}},
		{`INSERT INTO voice_leases (id, user_id, channel_id, session_token_digest) VALUES ($1,$2,$3,$4)`, []any{lease, member, voice, digest[:]}},
	} {
		if _, err := pool.Exec(ctx, statement.query, statement.args...); err != nil {
			t.Fatal(err)
		}
	}
	repository := New(NewPoolDatabase(pool))
	check := func(wantChannels, wantLeases int) {
		t.Helper()
		channels, err := repository.ListVisible(ctx, actor)
		if err != nil || len(channels) != wantChannels {
			t.Fatalf("channels=%+v err=%v want=%d", channels, err, wantChannels)
		}
		if wantChannels > 0 && (channels[0].ID != voice || len(channels[0].Leases) != wantLeases) {
			t.Fatalf("voice roster=%+v want leases=%d", channels[0], wantLeases)
		}
	}
	check(1, 1)
	if _, err := pool.Exec(ctx, `UPDATE sessions SET expires_at=now()-interval '1 second' WHERE token_digest=$1`, digest[:]); err != nil {
		t.Fatal(err)
	}
	check(1, 0)
	if _, err := pool.Exec(ctx, `UPDATE sessions SET expires_at=now()+interval '180 days',last_active_at=now()-interval '31 days' WHERE token_digest=$1`, digest[:]); err != nil {
		t.Fatal(err)
	}
	check(1, 0)
	if _, err := pool.Exec(ctx, `UPDATE sessions SET last_active_at=now() WHERE token_digest=$1`, digest[:]); err != nil {
		t.Fatal(err)
	}
	check(1, 1)
	if _, err := pool.Exec(ctx, `UPDATE sessions SET revoked_at = now() WHERE token_digest = $1`, digest[:]); err != nil {
		t.Fatal(err)
	}
	check(1, 0)
	if _, err := pool.Exec(ctx, `UPDATE sessions SET revoked_at = NULL WHERE token_digest = $1`, digest[:]); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `UPDATE users SET blocked_at = now() WHERE id = $1`, member); err != nil {
		t.Fatal(err)
	}
	check(1, 0)
	if _, err := pool.Exec(ctx, `UPDATE users SET blocked_at = NULL WHERE id = $1`, member); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `UPDATE voice_leases SET revoked_at = now(), revocation_reason = 'KICK' WHERE id = $1`, lease); err != nil {
		t.Fatal(err)
	}
	check(1, 0)
	if _, err := pool.Exec(ctx, `UPDATE channels SET archived_at = now() WHERE id = $1`, voice); err != nil {
		t.Fatal(err)
	}
	check(0, 0)
}
