package eventhub

import (
	"context"
	"time"
	incident "voice-platform/backend/internal/observability/observe_incidents"

	"github.com/google/uuid"
	causal "voice-platform/backend/internal/observability/causal_reference"
)

func replayable(kind string) bool {
	switch kind {
	case "message.created", "message.updated", "message.deleted",
		"message.reactions_updated", "message.pins_updated", "direct_message.reactions_updated",
		"direct_message.message_created", "direct_message.message_updated", "direct_message.message_deleted",
		"channel.updated", "guild.profile.updated", "member.profile.updated", "voice.lease_revoked":
		return true
	default:
		return false
	}
}

func (hub *Hub) persist(ctx context.Context, event Event, recipients []string, required bool) (Event, error) {
	if !event.Cause.Valid() {
		event.Cause = causal.From(ctx)
	}
	hub.mu.Lock()
	journal := hub.journal
	if hub.broken && journal != nil && replayable(event.Kind) {
		hub.bootEpoch = uuid.NewString()
	}
	epoch := hub.bootEpoch
	hub.mu.Unlock()
	if required && journal == nil {
		return event, ErrJournalUnavailable
	}
	if required && !replayable(event.Kind) {
		return event, ErrJournalUnavailable
	}
	if !replayable(event.Kind) || journal == nil {
		return event, nil
	}
	event = epochEvent(event, epoch)
	started := time.Now()
	appendErr := journal.Append(ctx, event, recipients, epoch)
	incident.Observe("realtime_journal", started, appendErr)
	if err := appendErr; err != nil {
		hub.breakContinuity()
		return event, err
	}
	hub.mu.Lock()
	hub.broken = false
	hub.mu.Unlock()
	return event, nil
}

// The voice outbox uses a stable source identifier for retries. Namespacing it
// by process epoch preserves retry deduplication without making a new boot's
// cursor indistinguishable from a journal row written before a crash.
func epochEvent(event Event, epoch string) Event {
	if event.Kind == "voice.lease_revoked" {
		event.EventID = uuid.NewSHA1(uuid.NameSpaceOID, []byte(epoch+":"+event.EventID)).String()
	}
	return event
}

func (hub *Hub) breakContinuity() {
	hub.mu.Lock()
	defer hub.mu.Unlock()
	hub.broken = true
	for subscription := range hub.subscribers {
		if !subscription.dropped {
			subscription.captureCriticalLocked()
		}
		subscription.dropped = true
		select {
		case subscription.overflowed <- struct{}{}:
		default:
		}
	}
}

func backgroundWriteContext() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 5*time.Second)
}
