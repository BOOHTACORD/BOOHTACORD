package listconnectedparticipants

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	presence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

func TestMatchedLeaseIsRetainedOnlyAsInternalProof(t *testing.T) {
	visible := visibleFunc(func(context.Context, string) ([]Channel, error) {
		return []Channel{{ID: channelID, Leases: []Lease{{ID: leaseID, AccountID: memberID, DisplayName: "Test"}}}}, nil
	})
	source := sourceFunc(func(context.Context, []string) (map[string][]presence.ConnectedLease, error) {
		return map[string][]presence.ConnectedLease{channelID: {{LeaseID: leaseID}}}, nil
	})
	result, err := New(visible, source).List(context.Background(), actorID)
	if err != nil || len(result.Channels) != 1 || len(result.Channels[0].Participants) != 1 {
		t.Fatalf("result=%+v err=%v", result, err)
	}
	if result.Channels[0].Participants[0].LeaseID != leaseID {
		t.Fatal("matched lease proof missing")
	}
	encoded, err := json.Marshal(result)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(encoded), "lease") || strings.Contains(string(encoded), leaseID) {
		t.Fatal("internal proof leaked into JSON")
	}
}
