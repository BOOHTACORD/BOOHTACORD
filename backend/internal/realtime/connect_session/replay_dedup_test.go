package connectsession

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/coder/websocket/wsjson"
	"voice-platform/backend/internal/identity/authenticate_session"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestReplaySuppressesLiveCopyQueuedDuringHistoryQuery(t *testing.T) {
	first := eventhub.Event{EventID: "22222222-2222-4222-8222-222222222222", Kind: "channel.updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"revision": 2}}
	second := eventhub.Event{EventID: "33333333-3333-4333-8333-333333333333", Kind: "channel.updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"revision": 3}}
	hub := eventhub.New(8)
	journal := &replayJournal{events: []eventhub.Event{first}}
	journal.replayed = func() { hub.Publish(first) }
	hub.SetJournal(journal)
	auth := authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
		return authenticatesession.Principal{AccountID: "44444444-4444-4444-8444-444444444444"}, nil
	})
	connection, closeSocket := openReplaySocket(t, hub, auth)
	defer closeSocket()
	for _, kind := range []string{"connection.ready", "channel.updated", "presence.snapshot", "presence.changed"} {
		var event Event
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		err := wsjson.Read(ctx, connection, &event)
		cancel()
		if err != nil || event.Kind != kind {
			t.Fatalf("got %#v / %v, want %s", event, err, kind)
		}
	}
	hub.Publish(second)
	var next Event
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := wsjson.Read(ctx, connection, &next); err != nil || next.EventID != second.EventID {
		t.Fatalf("duplicate replayed or missing live hint: %#v / %v", next, err)
	}
}

func TestSocketDeliversRevocationAfterReplayQueueOverflow(t *testing.T) {
	const account = "44444444-4444-4444-8444-444444444444"
	hub := eventhub.New(64)
	journal := &replayJournal{}
	journal.replayed = func() {
		for index := 0; index < 65; index++ {
			hub.PublishToAccounts([]string{account}, eventhub.Event{EventID: fmt.Sprint(index), Kind: "message.updated"})
		}
		hub.PublishToAccounts([]string{account}, eventhub.Event{EventID: "revoked", Kind: "voice.lease_revoked", Payload: map[string]any{"lease_id": "synthetic", "reason": "KICK"}})
	}
	hub.SetJournal(journal)
	auth := authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
		return authenticatesession.Principal{AccountID: account}, nil
	})
	connection, closeSocket := openReplaySocket(t, hub, auth)
	defer closeSocket()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	seenResync, seenRevoke := false, false
	for index := 0; index < 8 && !(seenResync && seenRevoke); index++ {
		var event Event
		if err := wsjson.Read(ctx, connection, &event); err != nil {
			t.Fatalf("socket closed before both controls: %v", err)
		}
		seenResync = seenResync || event.Kind == "connection.resync_required"
		seenRevoke = seenRevoke || event.Kind == "voice.lease_revoked"
	}
	if !seenResync || !seenRevoke {
		t.Fatalf("resync=%t revoke=%t", seenResync, seenRevoke)
	}
}

func TestReplayDoesNotSuppressDifferentKindWithSameID(t *testing.T) {
	first := eventhub.Event{EventID: "22222222-2222-4222-8222-222222222222", Kind: "channel.updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"revision": 2}}
	second := eventhub.Event{EventID: first.EventID, Kind: "message.updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"revision": 3}}
	hub := eventhub.New(8)
	hub.SetJournal(&replayJournal{events: []eventhub.Event{first}})
	auth := authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
		return authenticatesession.Principal{AccountID: "44444444-4444-4444-8444-444444444444"}, nil
	})
	connection, closeSocket := openReplaySocket(t, hub, auth)
	defer closeSocket()
	for _, kind := range []string{"connection.ready", "channel.updated", "presence.snapshot", "presence.changed"} {
		var event Event
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		err := wsjson.Read(ctx, connection, &event)
		cancel()
		if err != nil || event.Kind != kind {
			t.Fatalf("initial event kind=%q error=%v, want %q", event.Kind, err, kind)
		}
	}
	hub.Publish(second)
	var next Event
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := wsjson.Read(ctx, connection, &next); err != nil || next.Kind != second.Kind || next.EventID != second.EventID {
		t.Fatalf("different event kind suppressed: kind=%q error=%v", next.Kind, err)
	}
}
