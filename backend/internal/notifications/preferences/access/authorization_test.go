package preferencesaccess

import (
	"context"
	"testing"
	p "voice-platform/backend/internal/notifications/preferences"
)

func TestPairMembershipHasNoAdministratorBypass(t *testing.T) {
	r := New(fixturePool(t))
	ctx := context.Background()
	target := p.Override{Kind: "DIRECT_MESSAGE", ID: pair}
	for _, test := range []struct {
		actor string
		want  bool
	}{{owner, true}, {peer, true}, {outsider, false}} {
		got, err := r.Allowed(ctx, test.actor, target)
		if err != nil || got != test.want {
			t.Fatalf("actor=%s allowed=%v err=%v", test.actor, got, err)
		}
	}
	target.ID = "77777777-7777-4777-8777-777777777777"
	if got, err := r.Allowed(ctx, owner, target); err != nil || got {
		t.Fatal(got, err)
	}
}
func TestArchiveAndBlockedAccountLoseAccess(t *testing.T) {
	pool := fixturePool(t)
	r := New(pool)
	ctx := context.Background()
	target := p.Override{Kind: "CHANNEL", ID: channel}
	if got, err := r.Allowed(ctx, owner, target); err != nil || !got {
		t.Fatal(got, err)
	}
	if _, err := pool.Exec(ctx, `UPDATE channels SET archived_at=now() WHERE id=$1`, channel); err != nil {
		t.Fatal(err)
	}
	if got, err := r.Allowed(ctx, owner, target); err != nil || got {
		t.Fatal(got, err)
	}
	if _, err := pool.Exec(ctx, `UPDATE users SET blocked_at=now() WHERE id=$1`, owner); err != nil {
		t.Fatal(err)
	}
	if got, err := r.Allowed(ctx, owner, p.Override{Kind: "DIRECT_MESSAGE", ID: pair}); err != nil || got {
		t.Fatal(got, err)
	}
}
