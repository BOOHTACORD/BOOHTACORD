package replayeventpostgres

import (
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

var ErrInvalidHint = errors.New("invalid durable realtime hint")

func validateHint(event eventhub.Event, recipients []string) error {
	if _, err := uuid.Parse(event.EventID); err != nil || event.OccurredAt.IsZero() || event.OccurredAt.After(time.Now().Add(time.Minute)) {
		return ErrInvalidHint
	}
	var required []string
	private := false
	strict := false
	switch event.Kind {
	case "message.reactions_updated", "message.pins_updated":
		required, strict = []string{"channel_id", "message_id"}, true
	case "direct_message.reactions_updated":
		required, private, strict = []string{"direct_message_id", "message_id"}, true, true
	case "message.created", "message.updated", "message.deleted":
		required = []string{"channel_id", "message_id"}
	case "direct_message.message_created", "direct_message.message_updated", "direct_message.message_deleted":
		required, private = []string{"direct_message_id", "message_id"}, true
	case "voice.lease_revoked":
		required, private = []string{"lease_id", "reason"}, true
	case "channel.updated", "guild.profile.updated":
		required = []string{"revision"}
	case "member.profile.updated":
		required = []string{"user_id", "revision"}
	default:
		return ErrInvalidHint
	}
	if len(recipients) > 0 != private || len(event.Payload) < len(required) || len(event.Payload) > len(required)+1 || strict && len(event.Payload) != len(required) {
		return ErrInvalidHint
	}
	for _, accountID := range recipients {
		if _, err := uuid.Parse(accountID); err != nil {
			return ErrInvalidHint
		}
	}
	for key, value := range event.Payload {
		switch key {
		case "channel_id", "message_id", "direct_message_id", "lease_id", "user_id", "target_channel_id":
			identifier, ok := value.(string)
			if !ok {
				return ErrInvalidHint
			}
			if _, err := uuid.Parse(identifier); err != nil {
				return ErrInvalidHint
			}
		case "revision":
			switch number := value.(type) {
			case int:
				if number < 1 {
					return ErrInvalidHint
				}
			case int64:
				if number < 1 {
					return ErrInvalidHint
				}
			case float64:
				if number < 1 || number != float64(int64(number)) {
					return ErrInvalidHint
				}
			default:
				return ErrInvalidHint
			}
		case "reason":
			if !allowedReason(value) {
				return ErrInvalidHint
			}
		default:
			return fmt.Errorf("%w: unexpected field", ErrInvalidHint)
		}
	}
	for _, key := range required {
		if _, ok := event.Payload[key]; !ok {
			return ErrInvalidHint
		}
	}
	if event.Kind == "voice.lease_revoked" {
		_, hasTarget := event.Payload["target_channel_id"]
		reason, _ := event.Payload["reason"].(string)
		if (reason == "AFK_MOVE") != hasTarget {
			return ErrInvalidHint
		}
		return nil
	}
	if len(event.Payload) == len(required)+1 {
		if _, ok := event.Payload["revision"]; !ok {
			return ErrInvalidHint
		}
		if event.Kind == "channel.updated" || event.Kind == "guild.profile.updated" || event.Kind == "member.profile.updated" {
			return ErrInvalidHint
		}
	}
	return nil
}
