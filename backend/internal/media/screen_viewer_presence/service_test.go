package screenviewerpresence

import (
	"context"
	"errors"
	"testing"
)

type testAuthority struct {
	ownerAccount, viewerAccount, channel string
	err                                  error
}

func (authority testAuthority) AuthorizeOwner(context.Context, Principal, string) (string, string, error) {
	return authority.channel, authority.ownerAccount, authority.err
}
func (authority testAuthority) AuthorizeViewer(context.Context, Principal, string, string) (string, string, string, error) {
	return authority.channel, authority.ownerAccount, authority.viewerAccount, authority.err
}

type testPublication struct {
	track string
	err   error
	calls int
}

func (publication *testPublication) CurrentTrack(context.Context, string, string) (string, error) {
	publication.calls++
	return publication.track, publication.err
}

type testStore struct {
	watching                             map[string]bool
	viewers                              []string
	watchCalls, unwatchCalls, clearCalls int
}

func (store *testStore) Watching(ownerLease, viewerLease, track string) bool {
	return store.watching[ownerLease+viewerLease+track]
}
func (store *testStore) Watch(ownerLease, _ string, viewerLease, viewerAccount, track string) (bool, error) {
	store.watchCalls++
	key := ownerLease + viewerLease + track
	changed := !store.watching[key]
	store.watching[key] = true
	if changed {
		store.viewers = append(store.viewers, viewerAccount)
	}
	return changed, nil
}
func (store *testStore) Unwatch(string, string, string) bool { store.unwatchCalls++; return true }
func (store *testStore) Viewers(string, string) []string {
	return append([]string(nil), store.viewers...)
}
func (store *testStore) Clear(string, string) bool { store.clearCalls++; return true }

type testHints struct{ accounts []string }

func (hints *testHints) Changed(accountID string) { hints.accounts = append(hints.accounts, accountID) }

func TestViewerHeartbeatIsAuthorizedAndOnlyFirstReportNeedsPublicationLookup(t *testing.T) {
	store := &testStore{watching: map[string]bool{}}
	publication := &testPublication{track: "TR_screen"}
	hints := &testHints{}
	service, err := New(testAuthority{channel: "channel", ownerAccount: "owner-account", viewerAccount: "viewer-account"}, publication, store, hints)
	if err != nil {
		t.Fatal(err)
	}
	principal := Principal{AccountID: "viewer-account"}
	if err := service.Watch(context.Background(), principal, "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222", "TR_screen"); err != nil {
		t.Fatal(err)
	}
	if err := service.Watch(context.Background(), principal, "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222", "TR_screen"); err != nil {
		t.Fatal(err)
	}
	if publication.calls != 1 || store.watchCalls != 2 || len(hints.accounts) != 1 || hints.accounts[0] != "owner-account" {
		t.Fatalf("publication lookups=%d store writes=%d hints=%v", publication.calls, store.watchCalls, hints.accounts)
	}
}

func TestViewerCannotAnnounceAnInactiveOrDifferentScreenTrack(t *testing.T) {
	store := &testStore{watching: map[string]bool{}}
	publication := &testPublication{track: "TR_current"}
	service, err := New(testAuthority{channel: "channel", ownerAccount: "owner-account", viewerAccount: "viewer-account"}, publication, store, nil)
	if err != nil {
		t.Fatal(err)
	}
	err = service.Watch(context.Background(), Principal{AccountID: "viewer-account"}, "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222", "TR_old")
	if !errors.Is(err, ErrDenied) || store.watchCalls != 0 {
		t.Fatalf("error=%v writes=%d", err, store.watchCalls)
	}
}

func TestOwnerCanReadOnlyItsCurrentShareAndClearItsAudience(t *testing.T) {
	store := &testStore{watching: map[string]bool{}, viewers: []string{"viewer-a", "viewer-b"}}
	publication := &testPublication{track: "TR_current"}
	hints := &testHints{}
	service, err := New(testAuthority{channel: "channel", ownerAccount: "owner-account"}, publication, store, hints)
	if err != nil {
		t.Fatal(err)
	}
	viewers, err := service.Viewers(context.Background(), Principal{AccountID: "owner-account"}, "22222222-2222-4222-8222-222222222222")
	if err != nil || len(viewers) != 2 || viewers[0] != "viewer-a" {
		t.Fatalf("viewers=%v err=%v", viewers, err)
	}
	if err := service.ClearOwner(context.Background(), Principal{AccountID: "owner-account"}, "22222222-2222-4222-8222-222222222222", "TR_current"); err != nil {
		t.Fatal(err)
	}
	if store.clearCalls != 1 || len(hints.accounts) != 1 || hints.accounts[0] != "owner-account" {
		t.Fatalf("clears=%d hints=%v", store.clearCalls, hints.accounts)
	}
}

func TestCrossChannelViewerAndNonOwnerReadAreDenied(t *testing.T) {
	store := &testStore{watching: map[string]bool{}}
	service, err := New(testAuthority{err: ErrDenied}, &testPublication{track: "TR_screen"}, store, nil)
	if err != nil {
		t.Fatal(err)
	}
	principal := Principal{AccountID: "outsider"}
	if err := service.Watch(context.Background(), principal, "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222", "TR_screen"); !errors.Is(err, ErrDenied) {
		t.Fatalf("watch error=%v", err)
	}
	if _, err := service.Viewers(context.Background(), principal, "22222222-2222-4222-8222-222222222222"); !errors.Is(err, ErrDenied) {
		t.Fatalf("list error=%v", err)
	}
	if store.watchCalls != 0 {
		t.Fatalf("stored unauthorized viewer %d times", store.watchCalls)
	}
}
