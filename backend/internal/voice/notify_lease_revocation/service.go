package notifyleaserevocation

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	causal "voice-platform/backend/internal/observability/causal_reference"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Store interface {
	Claim(context.Context, int) ([]Item, error)
	MarkEmitted(context.Context, Item) error
}

type Publisher interface {
	PublishToAccountsDurable(context.Context, []string, eventhub.Event) error
}

type Service struct {
	store     Store
	publisher Publisher
}

func New(store Store, publisher Publisher) Service {
	return Service{store: store, publisher: publisher}
}

func (service Service) Dispatch(context context.Context, limit int) (int, error) {
	items, err := service.store.Claim(context, limit)
	if err != nil {
		return 0, fmt.Errorf("claim lease revocation notifications: %w", err)
	}
	for index, item := range items {
		payload := map[string]any{"lease_id": item.LeaseID, "reason": item.Reason}
		if item.TargetChannelID != nil {
			payload["target_channel_id"] = *item.TargetChannelID
		}
		err := service.publisher.PublishToAccountsDurable(context, []string{item.UserID}, eventhub.Event{
			EventID:    uuid.NewSHA1(uuid.NameSpaceOID, []byte("voice.lease_revoked:"+item.LeaseID)).String(),
			Kind:       "voice.lease_revoked",
			Cause:      causal.Decode(item.TraceCause),
			OccurredAt: item.RequestedAt,
			Payload:    payload,
		})
		if err != nil {
			return index, fmt.Errorf("persist lease revocation event: %w", err)
		}
		if err := service.store.MarkEmitted(context, item); err != nil {
			return index, fmt.Errorf("mark lease revocation emitted: %w", err)
		}
	}
	return len(items), nil
}
