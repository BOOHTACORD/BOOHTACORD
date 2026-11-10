package connectsession

import eventhub "voice-platform/backend/internal/realtime/event_hub"

func presenceEvent(accountID, presence string, newID Identifier, now Clock) eventhub.Event {
	return eventhub.Event{EventID: newID(), Kind: "presence.changed", OccurredAt: now().UTC(), Payload: map[string]any{"user_id": accountID, "presence": presence}}
}
