package authorizerosterdelivery

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

const actor = "11111111-1111-4111-8111-111111111111"
const room = "22222222-2222-4222-8222-222222222222"
const member = "33333333-3333-4333-8333-333333333333"
const lease = "44444444-4444-4444-8444-444444444444"

type authFunc func(context.Context, string) (auth.Principal, error)

func (f authFunc) Authenticate(ctx context.Context, value string) (auth.Principal, error) {
	return f(ctx, value)
}

type repoFunc func(context.Context, string) ([]roster.Channel, error)

func (f repoFunc) ListVisible(ctx context.Context, id string) ([]roster.Channel, error) {
	return f(ctx, id)
}

func fixture() (auth.Principal, roster.Result, []roster.Channel) {
	principal := auth.Principal{AccountID: actor, SessionDigest: sha256.Sum256([]byte("session"))}
	snapshot := roster.Result{Channels: []roster.ChannelRoster{{ChannelID: room, Participants: []roster.Participant{{LeaseID: lease, AccountID: member, DisplayName: "Test"}}}}}
	visible := []roster.Channel{{ID: room, Leases: []roster.Lease{{ID: lease, AccountID: member, DisplayName: "Test"}}}}
	return principal, snapshot, visible
}

func TestValidSnapshotAndEmptyRosterRequireCurrentSession(t *testing.T) {
	principal, snapshot, visible := fixture()
	calls := 0
	guard := New(authFunc(func(context.Context, string) (auth.Principal, error) { calls++; return principal, nil }), repoFunc(func(context.Context, string) ([]roster.Channel, error) { return visible, nil }))
	if err := guard.Check(context.Background(), "opaque", principal, snapshot); err != nil {
		t.Fatal(err)
	}
	if calls != 2 {
		t.Fatalf("session checks = %d", calls)
	}
	visible = nil
	if err := guard.Check(context.Background(), "opaque", principal, roster.Result{}); err != nil {
		t.Fatal(err)
	}
}

func TestStaleTopologyLeaseAndNameNeverAuthorize(t *testing.T) {
	principal, snapshot, visible := fixture()
	for _, current := range [][]roster.Channel{
		nil,
		{{ID: room}},
		{{ID: room, Leases: []roster.Lease{{ID: "55555555-5555-4555-8555-555555555555", AccountID: member, DisplayName: "Test"}}}},
		{{ID: room, Leases: []roster.Lease{{ID: lease, AccountID: member, DisplayName: "Renamed"}}}},
		append(visible, roster.Channel{ID: "66666666-6666-4666-8666-666666666666"}),
	} {
		guard := New(authFunc(func(context.Context, string) (auth.Principal, error) { return principal, nil }), repoFunc(func(context.Context, string) ([]roster.Channel, error) { return current, nil }))
		if err := guard.Check(context.Background(), "opaque", principal, snapshot); !errors.Is(err, ErrStale) {
			t.Fatalf("stale snapshot accepted: %v", err)
		}
	}
}

func TestMissingOrDuplicatedLeaseProofIsRejected(t *testing.T) {
	principal, snapshot, visible := fixture()
	guard := New(authFunc(func(context.Context, string) (auth.Principal, error) { return principal, nil }), repoFunc(func(context.Context, string) ([]roster.Channel, error) { return visible, nil }))
	snapshot.Channels[0].Participants[0].LeaseID = ""
	if err := guard.Check(context.Background(), "opaque", principal, snapshot); !errors.Is(err, ErrStale) {
		t.Fatalf("missing proof: %v", err)
	}
	_, snapshot, _ = fixture()
	snapshot.Channels[0].Participants = append(snapshot.Channels[0].Participants, snapshot.Channels[0].Participants[0])
	if err := guard.Check(context.Background(), "opaque", principal, snapshot); !errors.Is(err, ErrStale) {
		t.Fatalf("duplicate proof: %v", err)
	}
}
