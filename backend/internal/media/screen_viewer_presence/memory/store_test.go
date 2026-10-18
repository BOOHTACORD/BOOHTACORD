package memory

import (
	"testing"
	"time"

	presence "voice-platform/backend/internal/media/screen_viewer_presence"
)

func TestWatchHeartbeatExpiresWithoutChangingAudienceUntilStale(t *testing.T) {
	now := time.Unix(100, 0)
	var changed []string
	store := newStore(func() time.Time { return now }, 20*time.Second, 4, func(owner string) { changed = append(changed, owner) })
	defer store.Close()

	first, err := store.Watch("owner-lease", "owner", "viewer-lease", "viewer", "TR_screen")
	if err != nil || !first {
		t.Fatalf("changed=%v err=%v", first, err)
	}
	second, err := store.Watch("owner-lease", "owner", "viewer-lease", "viewer", "TR_screen")
	if err != nil || second {
		t.Fatalf("heartbeat changed=%v err=%v", second, err)
	}
	if got := store.Viewers("owner-lease", "TR_screen"); len(got) != 1 || got[0] != "viewer" {
		t.Fatalf("viewers=%v", got)
	}
	if len(changed) != 0 {
		t.Fatalf("heartbeat notifications=%v", changed)
	}

	now = now.Add(21 * time.Second)
	if got := store.Viewers("owner-lease", "TR_screen"); len(got) != 0 {
		t.Fatalf("expired viewers=%v", got)
	}
	if len(changed) != 1 || changed[0] != "owner" {
		t.Fatalf("expiry notifications=%v", changed)
	}
}

func TestOwnerAndViewerRemovalOnlyAffectTheirOwnEntries(t *testing.T) {
	var changed []string
	store := newStore(time.Now, time.Minute, 4, func(owner string) { changed = append(changed, owner) })
	defer store.Close()
	_, _ = store.Watch("owner-a", "account-a", "viewer-a", "member-a", "TR_a")
	_, _ = store.Watch("owner-a", "account-a", "viewer-b", "member-b", "TR_a")
	_, _ = store.Watch("owner-b", "account-b", "viewer-a", "member-a", "TR_b")

	if !store.Unwatch("owner-a", "viewer-a", "TR_a") {
		t.Fatal("viewer removal was not recorded")
	}
	if got := store.Viewers("owner-a", "TR_a"); len(got) != 1 || got[0] != "member-b" {
		t.Fatalf("owner-a viewers=%v", got)
	}
	if got := store.Viewers("owner-b", "TR_b"); len(got) != 1 || got[0] != "member-a" {
		t.Fatalf("owner-b viewers=%v", got)
	}
	if !store.Clear("owner-a", "TR_a") {
		t.Fatal("owner cleanup was not recorded")
	}
	if got := store.Viewers("owner-a", "TR_a"); len(got) != 0 {
		t.Fatalf("cleared owner viewers=%v", got)
	}
	if len(changed) != 0 {
		t.Fatalf("explicit mutations notified unexpectedly: %v", changed)
	}
}

func TestOldTrackUnsubscribeCannotClearReplacementPresence(t *testing.T) {
	store := newStore(time.Now, time.Minute, 4, nil)
	defer store.Close()
	if _, err := store.Watch("owner", "owner-account", "viewer", "viewer-account", "TR_new"); err != nil {
		t.Fatal(err)
	}
	if store.Unwatch("owner", "viewer", "TR_old") {
		t.Fatal("an old track unsubscribe removed the replacement")
	}
	if got := store.Viewers("owner", "TR_new"); len(got) != 1 || got[0] != "viewer-account" {
		t.Fatalf("replacement viewers = %v", got)
	}
	if !store.Unwatch("owner", "viewer", "TR_new") {
		t.Fatal("current track unsubscribe did not remove the viewer")
	}
}

func TestCapacityIsBoundedAndCloseStopsTimers(t *testing.T) {
	store := newStore(time.Now, time.Hour, 1, nil)
	defer store.Close()
	if _, err := store.Watch("owner-a", "account-a", "viewer-a", "member-a", "TR_a"); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Watch("owner-b", "account-b", "viewer-b", "member-b", "TR_b"); err != presence.ErrCapacity {
		t.Fatalf("capacity error=%v", err)
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Watch("owner-a", "account-a", "viewer-a", "member-a", "TR_a"); err != ErrClosed {
		t.Fatalf("closed error=%v", err)
	}
}
