package screentelemetryrelay

import (
	"context"
	"encoding/json"
	"errors"
	"sort"
	"strconv"
	"time"

	"github.com/google/uuid"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Service struct{ dependencies Dependencies }

func New(dependencies Dependencies) (Service, error) {
	if dependencies.Authority == nil || dependencies.Publications == nil || dependencies.Watchers == nil || dependencies.Audience == nil || dependencies.Sequences == nil || dependencies.Publisher == nil {
		return Service{}, ErrUnavailable
	}
	if dependencies.Now == nil {
		dependencies.Now = time.Now
	}
	return Service{dependencies: dependencies}, nil
}

func formatGeneration(value uint64) string { return strconv.FormatUint(value, 10) }

func (service Service) Publish(ctx context.Context, principal Principal, ownerLeaseID string, envelope ScreenTelemetryEnvelopeV1) error {
	if ctx == nil || uuid.Validate(principal.AccountID) != nil || uuid.Validate(ownerLeaseID) != nil || envelope.Validate() != nil {
		return ErrInvalid
	}
	channelID, ownerAccountID, err := service.dependencies.Authority.AuthorizeOwner(ctx, principal, ownerLeaseID)
	if errors.Is(err, ErrDenied) || err == nil && ownerAccountID != principal.AccountID {
		return ErrDenied
	}
	if err != nil {
		return ErrUnavailable
	}
	publication, err := service.dependencies.Publications.CurrentPublication(ctx, channelID, ownerLeaseID, ownerAccountID)
	if errors.Is(err, ErrNoPublication) {
		return ErrDenied
	}
	if err != nil {
		return ErrUnavailable
	}
	if publication.TrackSID == "" || publication.Scope.AccountID != ownerAccountID || publication.Scope.RoomID != "voice:"+channelID ||
		publication.Scope.MediaSessionID != envelope.MediaSessionID || publication.Scope.PublicationGeneration != envelope.PublicationGeneration {
		return ErrStale
	}

	now := service.dependencies.Now().UTC()
	if err := service.dependencies.Sequences.Accept(ownerLeaseID, envelope.MediaSessionID, envelope.PublicationGeneration, envelope.Sequence, now); err != nil {
		return err
	}

	watchers := service.dependencies.Watchers.Watchers(ownerLeaseID, publication.TrackSID)
	watcherIDs := make([]string, 0, len(watchers))
	for _, watcher := range watchers {
		if uuid.Validate(watcher.LeaseID) == nil {
			watcherIDs = append(watcherIDs, watcher.LeaseID)
		}
	}
	if len(watcherIDs) == 0 {
		return nil
	}
	authorized, err := service.dependencies.Audience.ActiveWatchers(ctx, ownerLeaseID, watcherIDs)
	if err != nil {
		return ErrUnavailable
	}
	allowed := make(map[string]struct{}, len(authorized))
	for _, watcher := range authorized {
		if uuid.Validate(watcher.LeaseID) == nil && uuid.Validate(watcher.AccountID) == nil {
			allowed[watcher.LeaseID+"\x00"+watcher.AccountID] = struct{}{}
		}
	}
	accounts := make(map[string]struct{}, len(authorized))
	for _, watcher := range watchers {
		if _, ok := allowed[watcher.LeaseID+"\x00"+watcher.AccountID]; ok {
			accounts[watcher.AccountID] = struct{}{}
		}
	}
	if len(accounts) == 0 {
		return nil
	}
	recipients := make([]string, 0, len(accounts))
	for accountID := range accounts {
		recipients = append(recipients, accountID)
	}
	sort.Strings(recipients)

	payload := map[string]any{
		"owner_lease_id":     ownerLeaseID,
		"server_received_at": now.Format(time.RFC3339Nano),
		"envelope":           envelope,
	}
	encoded, err := json.Marshal(payload)
	if err != nil || len(encoded) > MaxEnvelopeBytes {
		return ErrInvalid
	}
	key := ownerLeaseID + "/" + envelope.MediaSessionID + "/" + formatGeneration(envelope.PublicationGeneration)
	event := eventhub.Event{EventID: uuid.NewString(), Kind: "screen_telemetry.updated", OccurredAt: now, Payload: payload, TransientKey: key}
	service.dependencies.Publisher.PublishToAccountsTransientCoalesced(recipients, event, key)
	return nil
}
