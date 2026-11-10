package listconnectedparticipants

import (
	"context"
	"errors"
	"testing"
	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

func TestListIntersectsLiveKitActiveWithCurrentLeaseAndIncludesEmptyRooms(t *testing.T) {
	otherID := "55555555-5555-4555-8555-555555555555"
	secondRoom := "66666666-6666-4666-8666-666666666666"
	listed := &repositoryStub{channels: []Channel{
		{ID: channelID, Leases: []Lease{{ID: leaseID, AccountID: memberID, DisplayName: "Мария"}}},
		{ID: secondRoom, Leases: []Lease{{ID: otherID, AccountID: otherID, DisplayName: "Не подключён"}}},
	}}
	presence := &presenceStub{connected: map[string][]snapshotlivekitpresence.ConnectedLease{
		channelID: {{LeaseID: leaseID, ScreenSharing: true, MicrophoneMuted: true}, {LeaseID: otherID}},
	}}
	result, err := New(listed, presence).List(context.Background(), actorID)
	if err != nil || len(result.Channels) != 2 {
		t.Fatalf("result=%+v err=%v", result, err)
	}
	first := result.Channels[0]
	if first.ChannelID != channelID || len(first.Participants) != 1 || first.Participants[0] != (Participant{LeaseID: leaseID, AccountID: memberID, DisplayName: "Мария", ScreenSharing: true, MicrophoneMuted: true}) {
		t.Fatalf("unexpected joined room: %+v", first)
	}
	if result.Channels[1].ChannelID != secondRoom || len(result.Channels[1].Participants) != 0 {
		t.Fatalf("lease-only room shown: %+v", result.Channels[1])
	}
}

func TestListFailsClosedOnRepositoryOrPresenceFailure(t *testing.T) {
	presence := &presenceStub{}
	_, err := New(&repositoryStub{err: errors.New("db unavailable")}, presence).List(context.Background(), actorID)
	if err == nil || presence.called {
		t.Fatalf("repository failure queried SFU: %v", err)
	}
	secondRoom := "66666666-6666-4666-8666-666666666666"
	presence = &presenceStub{err: snapshotlivekitpresence.ErrUnavailable}
	_, err = New(&repositoryStub{channels: []Channel{{ID: channelID}, {ID: secondRoom}}}, presence).List(context.Background(), actorID)
	if !errors.Is(err, ErrPresenceUnavailable) {
		t.Fatalf("presence failure = %v", err)
	}
}

func TestListRechecksLeaseAfterLiveKitSnapshot(t *testing.T) {
	secondRoom := "66666666-6666-4666-8666-666666666666"
	repository := &repositoryStub{
		channels: []Channel{{ID: channelID, Leases: []Lease{{ID: leaseID, AccountID: memberID, DisplayName: "Мария"}}}, {ID: secondRoom}},
		second:   []Channel{{ID: channelID}, {ID: secondRoom}},
	}
	presence := &presenceStub{connected: map[string][]snapshotlivekitpresence.ConnectedLease{channelID: {{LeaseID: leaseID}}}}
	result, err := New(repository, presence).List(context.Background(), actorID)
	if err != nil || repository.calls != 2 || len(result.Channels[0].Participants) != 0 {
		t.Fatalf("revoked lease leaked: result=%+v calls=%d err=%v", result, repository.calls, err)
	}
}

func TestListReportsSnapshotLoadWithoutActorOrRoomIDs(t *testing.T) {
	secondRoom := "66666666-6666-4666-8666-666666666666"
	observer := &snapshotObserver{}
	service := New(&repositoryStub{channels: []Channel{{ID: channelID}, {ID: secondRoom}}}, &presenceStub{connected: map[string][]snapshotlivekitpresence.ConnectedLease{}}, observer)
	if _, err := service.List(context.Background(), actorID); err != nil {
		t.Fatal(err)
	}
	if observer.calls != 1 || observer.rooms != 2 || observer.failed {
		t.Fatalf("observer = %+v", observer)
	}
}

func TestListReportsOnlyBoundedRosterFailureStages(t *testing.T) {
	secondRoom := "66666666-6666-4666-8666-666666666666"
	tests := []struct {
		name       string
		repository *repositoryStub
		presence   *presenceStub
		want       string
	}{
		{
			name:       "initial visibility query",
			repository: &repositoryStub{err: errors.New("sensitive database detail")},
			presence:   &presenceStub{},
			want:       "visibility_initial",
		},
		{
			name:       "LiveKit snapshot",
			repository: &repositoryStub{channels: []Channel{{ID: channelID}, {ID: secondRoom}}},
			presence:   &presenceStub{err: snapshotlivekitpresence.ErrUnavailable},
			want:       "presence_snapshot",
		},
		{
			name:       "ACL recheck",
			repository: &repositoryStub{channels: []Channel{{ID: channelID}, {ID: secondRoom}}, secondErr: errors.New("sensitive database detail")},
			presence:   &presenceStub{connected: map[string][]snapshotlivekitpresence.ConnectedLease{}},
			want:       "visibility_recheck",
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			observer := &snapshotObserver{}
			_, _ = New(test.repository, test.presence, observer).List(context.Background(), actorID)
			if len(observer.failures) != 1 || observer.failures[0] != test.want {
				t.Fatalf("failure stages = %v, want [%s]", observer.failures, test.want)
			}
		})
	}
}
