package screentelemetryrelay

import (
	"context"
	"time"

	"voice-platform/backend/internal/media/publish_screen_descriptor"
	presence "voice-platform/backend/internal/media/screen_viewer_presence"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Principal = presence.Principal

type Authority interface {
	AuthorizeOwner(context.Context, Principal, string) (channelID, ownerAccountID string, err error)
}

type PublicationVerifier interface {
	CurrentPublication(context.Context, string, string, string) (publish_screen_descriptor.Publication, error)
}

type WatcherStore interface {
	Watchers(string, string) []presence.Watcher
}

type AudienceAuthorizer interface {
	ActiveWatchers(context.Context, string, []string) ([]presence.Watcher, error)
}

type SequenceGate interface {
	Accept(string, string, uint64, uint64, time.Time) error
}

type Publisher interface {
	PublishToAccountsTransientCoalesced([]string, eventhub.Event, string)
}

type Dependencies struct {
	Authority    Authority
	Publications PublicationVerifier
	Watchers     WatcherStore
	Audience     AudienceAuthorizer
	Sequences    SequenceGate
	Publisher    Publisher
	Now          func() time.Time
}
