package listconnectedparticipants

import (
	"context"
	"time"
	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

type snapshotObserver struct {
	calls    int
	rooms    int
	failed   bool
	failures []string
}

func (observer *snapshotObserver) ObserveVoiceRosterSnapshot(_ time.Duration, rooms int, failed bool) {
	observer.calls++
	observer.rooms = rooms
	observer.failed = failed
}

func (observer *snapshotObserver) ObserveVoiceRosterFailure(stage string) {
	observer.failures = append(observer.failures, stage)
}

const (
	actorID   = "11111111-1111-4111-8111-111111111111"
	channelID = "22222222-2222-4222-8222-222222222222"
	memberID  = "33333333-3333-4333-8333-333333333333"
	leaseID   = "44444444-4444-4444-8444-444444444444"
)

type repositoryStub struct {
	channels  []Channel
	second    []Channel
	err       error
	secondErr error
	calls     int
}

func (stub *repositoryStub) ListVisible(_ context.Context, actor string) ([]Channel, error) {
	if actor != actorID {
		panic("wrong actor")
	}
	stub.calls++
	if stub.calls > 1 && stub.secondErr != nil {
		return nil, stub.secondErr
	}
	if stub.calls > 1 && stub.second != nil {
		return stub.second, nil
	}
	return stub.channels, stub.err
}

type presenceStub struct {
	connected map[string][]snapshotlivekitpresence.ConnectedLease
	err       error
	called    bool
}

func (stub *presenceStub) SnapshotRooms(_ context.Context, ids []string) (map[string][]snapshotlivekitpresence.ConnectedLease, error) {
	stub.called = true
	if len(ids) != 2 || ids[0] != channelID {
		panic("wrong visible rooms")
	}
	return stub.connected, stub.err
}
