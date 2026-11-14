package connectsession

import eventhub "voice-platform/backend/internal/realtime/event_hub"

func presenceEvent(accountID, presence string, newID Identifier, now Clock) eventhub.Event {
	payload := map[string]any{"user_id": accountID, "presence": presence}
	if presence == "online" {
		payload["activity_state"] = "active"
	}
	return eventhub.Event{EventID: newID(), Kind: "presence.changed", OccurredAt: now().UTC(), Payload: payload}
}
