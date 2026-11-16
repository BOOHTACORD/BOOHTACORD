package screentelemetryrelay

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"

	"voice-platform/backend/internal/media/publish_screen_descriptor"
	presence "voice-platform/backend/internal/media/screen_viewer_presence"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

const (
	ownerAccountID  = "11111111-1111-4111-8111-111111111111"
	viewerAccountID = "33333333-3333-4333-8333-333333333333"
	ownerLeaseID    = "22222222-2222-4222-8222-222222222222"
	viewerLeaseID   = "44444444-4444-4444-8444-444444444444"
	channelID       = "55555555-5555-4555-8555-555555555555"
)

type authorityStub struct{ err error }

func (stub authorityStub) AuthorizeOwner(context.Context, Principal, string) (string, string, error) {
	return channelID, ownerAccountID, stub.err
}

type publicationStub struct {
	publication publish_screen_descriptor.Publication
	err         error
}

func (stub publicationStub) CurrentPublication(context.Context, string, string, string) (publish_screen_descriptor.Publication, error) {
	return stub.publication, stub.err
}

type watcherStoreStub struct{ watchers []presence.Watcher }

func (stub watcherStoreStub) Watchers(string, string) []presence.Watcher { return stub.watchers }

type audienceStub struct {
	watchers []presence.Watcher
	ids      []string
	err      error
}

func (stub *audienceStub) ActiveWatchers(_ context.Context, owner string, ids []string) ([]presence.Watcher, error) {
	stub.ids = append([]string(nil), ids...)
	if owner != ownerLeaseID {
		return nil, errors.New("unexpected owner")
	}
	return stub.watchers, stub.err
}

type sequenceStub struct{ err error }

func (stub sequenceStub) Accept(string, string, uint64, uint64, time.Time) error { return stub.err }

type eventPublisherStub struct {
	accounts []string
	event    eventhub.Event
	key      string
	calls    int
}

func (stub *eventPublisherStub) PublishToAccountsTransientCoalesced(accounts []string, event eventhub.Event, key string) {
	stub.accounts = append([]string(nil), accounts...)
	stub.event, stub.key = event, key
	stub.calls++
}

func TestPublishTargetsOnlyReauthorizedActiveViewersOfCurrentPublication(t *testing.T) {
	watchers := []presence.Watcher{{LeaseID: viewerLeaseID, AccountID: viewerAccountID}, {LeaseID: "66666666-6666-4666-8666-666666666666", AccountID: "77777777-7777-4777-8777-777777777777"}}
	audience := &audienceStub{watchers: watchers[:1]}
	publisher := &eventPublisherStub{}
	publication := publish_screen_descriptor.Publication{TrackSID: "TR_private", Scope: publish_screen_descriptor.Scope{
		AccountID: ownerAccountID, RoomID: "voice:" + channelID, MediaSessionID: "session-a", PublicationGeneration: 4,
	}}
	service, err := New(Dependencies{Authority: authorityStub{}, Publications: publicationStub{publication: publication},
		Watchers: watcherStoreStub{watchers: watchers}, Audience: audience, Sequences: sequenceStub{}, Publisher: publisher,
		Now: func() time.Time { return time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC) }})
	if err != nil {
		t.Fatal(err)
	}
	principal := Principal{AccountID: ownerAccountID, SessionDigest: [32]byte{1}}
	if err := service.Publish(context.Background(), principal, ownerLeaseID, validEnvelope()); err != nil {
		t.Fatalf("publish: %v", err)
	}
	if publisher.calls != 1 || len(publisher.accounts) != 1 || publisher.accounts[0] != viewerAccountID {
		t.Fatalf("published to unauthorized audience: %+v", publisher)
	}
	if len(audience.ids) != 2 || audience.ids[0] != viewerLeaseID {
		t.Fatalf("active viewer leases not rechecked: %v", audience.ids)
	}
	if publisher.event.Kind != "screen_telemetry.updated" || publisher.key != ownerLeaseID+"/session-a/4" {
		t.Fatalf("event = %#v key=%q", publisher.event, publisher.key)
	}
	if got := publisher.event.Payload["owner_lease_id"]; got != ownerLeaseID {
		t.Fatalf("scope missing from payload: %#v", publisher.event.Payload)
	}
	serialized, err := json.Marshal(publisher.event)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(serialized), "TR_private") || strings.Contains(string(serialized), "SessionDigest") {
		t.Fatalf("private transport/session data escaped in event: %s", serialized)
	}
}

func TestPublishRejectsWrongGenerationOwnerAndOutOfOrderSamples(t *testing.T) {
	base := publish_screen_descriptor.Publication{TrackSID: "TR_private", Scope: publish_screen_descriptor.Scope{
		AccountID: ownerAccountID, RoomID: "voice:" + channelID, MediaSessionID: "session-a", PublicationGeneration: 4,
	}}
	newService := func(authority Authority, publication publish_screen_descriptor.Publication, sequenceErr error) (Service, *eventPublisherStub) {
		publisher := &eventPublisherStub{}
		service, err := New(Dependencies{Authority: authority, Publications: publicationStub{publication: publication},
			Watchers:  watcherStoreStub{watchers: []presence.Watcher{{LeaseID: viewerLeaseID, AccountID: viewerAccountID}}},
			Audience:  &audienceStub{watchers: []presence.Watcher{{LeaseID: viewerLeaseID, AccountID: viewerAccountID}}},
			Sequences: sequenceStub{err: sequenceErr}, Publisher: publisher, Now: time.Now})
		if err != nil {
			t.Fatal(err)
		}
		return service, publisher
	}

	wrongGeneration := base
	wrongGeneration.Scope.PublicationGeneration++
	service, publisher := newService(authorityStub{}, wrongGeneration, nil)
	if err := service.Publish(context.Background(), Principal{AccountID: ownerAccountID}, ownerLeaseID, validEnvelope()); !errors.Is(err, ErrStale) {
		t.Fatalf("wrong generation error = %v", err)
	}
	if publisher.calls != 0 {
		t.Fatal("wrong generation reached realtime recipients")
	}

	service, publisher = newService(authorityStub{err: ErrDenied}, base, nil)
	if err := service.Publish(context.Background(), Principal{AccountID: ownerAccountID}, ownerLeaseID, validEnvelope()); !errors.Is(err, ErrDenied) {
		t.Fatalf("inactive owner error = %v", err)
	}
	if publisher.calls != 0 {
		t.Fatal("inactive owner reached realtime recipients")
	}

	service, publisher = newService(authorityStub{}, base, ErrStale)
	if err := service.Publish(context.Background(), Principal{AccountID: ownerAccountID}, ownerLeaseID, validEnvelope()); !errors.Is(err, ErrStale) {
		t.Fatalf("out-of-order sample error = %v", err)
	}
	if publisher.calls != 0 {
		t.Fatal("out-of-order sample reached realtime recipients")
	}
}

func TestPublishDoesNotDeliverWithoutAnActiveSelectedViewer(t *testing.T) {
	publication := publish_screen_descriptor.Publication{TrackSID: "TR_private", Scope: publish_screen_descriptor.Scope{
		AccountID: ownerAccountID, RoomID: "voice:" + channelID, MediaSessionID: "session-a", PublicationGeneration: 4,
	}}
	publisher := &eventPublisherStub{}
	service, err := New(Dependencies{Authority: authorityStub{}, Publications: publicationStub{publication: publication},
		Watchers: watcherStoreStub{}, Audience: &audienceStub{}, Sequences: sequenceStub{}, Publisher: publisher, Now: time.Now})
	if err != nil {
		t.Fatal(err)
	}
	if err := service.Publish(context.Background(), Principal{AccountID: ownerAccountID}, ownerLeaseID, validEnvelope()); err != nil {
		t.Fatalf("publish without viewers: %v", err)
	}
	if publisher.calls != 0 {
		t.Fatal("telemetry was delivered without an active selected viewer")
	}
}

func TestPublishFailsClosedWhenViewerAclCannotBeRechecked(t *testing.T) {
	publication := publish_screen_descriptor.Publication{TrackSID: "TR_private", Scope: publish_screen_descriptor.Scope{
		AccountID: ownerAccountID, RoomID: "voice:" + channelID, MediaSessionID: "session-a", PublicationGeneration: 4,
	}}
	watchers := []presence.Watcher{{LeaseID: viewerLeaseID, AccountID: viewerAccountID}}
	publisher := &eventPublisherStub{}
	service, err := New(Dependencies{Authority: authorityStub{}, Publications: publicationStub{publication: publication},
		Watchers: watcherStoreStub{watchers: watchers}, Audience: &audienceStub{err: ErrUnavailable},
		Sequences: sequenceStub{}, Publisher: publisher, Now: time.Now})
	if err != nil {
		t.Fatal(err)
	}
	if err := service.Publish(context.Background(), Principal{AccountID: ownerAccountID}, ownerLeaseID, validEnvelope()); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("viewer ACL failure=%v", err)
	}
	if publisher.calls != 0 {
		t.Fatal("telemetry delivered without a successful ACL recheck")
	}
}
