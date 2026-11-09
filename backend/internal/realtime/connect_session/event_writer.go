package connectsession

import (
	"context"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func writeHubEvent(connection *websocket.Conn, authenticator sessionapi.Authenticator, cookie *http.Cookie, subscription *eventhub.Subscription, hub *eventhub.Hub, observer ConnectionObserver, replayedIDs map[string]struct{}, event eventhub.Event) bool {
	if _, replayed := replayedIDs[event.EventID]; replayed {
		delete(replayedIDs, event.EventID)
		return true
	}
	if (isPrivateDirectMessageEvent(event.Kind) || event.Kind == "session.state_changed") && !privateEventSessionValid(authenticator, cookie, subscription, observer) {
		_ = connection.Close(websocket.StatusPolicyViolation, "session is no longer valid")
		return false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if subscription.Supports("flow_tracing_v1") {
		event = hub.Correlate(ctx, subscription.AccountID(), event)
	}
	if err := wsjson.Write(ctx, connection, event); err != nil {
		return false
	}
	if metrics, ok := observer.(interface{ ObserveRealtimeEventDeliveryLatency(time.Duration) }); ok && !event.OccurredAt.IsZero() {
		if latency := time.Since(event.OccurredAt); latency >= 0 {
			metrics.ObserveRealtimeEventDeliveryLatency(latency)
		}
	}
	return true
}

func writeOverflow(connection *websocket.Conn, subscription *eventhub.Subscription, hub *eventhub.Hub, newID Identifier, now Clock) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if !writeEvent(ctx, connection, newID, now, "connection.resync_required", map[string]any{"reason": "event_overflow"}) {
		return false
	}
	if hub != nil && !writeEvent(ctx, connection, newID, now, "presence.snapshot", map[string]any{"online_user_ids": hub.OnlineAccounts()}) {
		return false
	}
	subscription.AcknowledgeOverflow()
	return true
}
