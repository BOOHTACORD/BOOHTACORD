package connectsession

import (
	"context"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func streamEvents(connection *websocket.Conn, authenticator sessionapi.Authenticator, cookie *http.Cookie, subscription *eventhub.Subscription, hub *eventhub.Hub, newID Identifier, now Clock, observer ConnectionObserver, replayedIDs map[string]struct{}, maintenance *observestate.Subscription) {
	closed := connection.CloseRead(context.Background()).Done()
	var events <-chan eventhub.Event
	var overflowed <-chan struct{}
	var maintenanceEvents <-chan observestate.State
	firstMaintenance := true
	if maintenance != nil {
		maintenanceEvents = maintenance.Events()
	}
	if subscription != nil {
		events, overflowed = subscription.Events(), subscription.Overflowed()
	}
	for {
		select {
		case <-closed:
			return
		case state, ok := <-maintenanceEvents:
			if !ok || !writeMaintenance(connection, state, firstMaintenance, newID, now) {
				return
			}
			firstMaintenance = false
		case event := <-events:
			if _, replayed := replayedIDs[event.EventID]; replayed {
				delete(replayedIDs, event.EventID)
				continue
			}
			if (isPrivateDirectMessageEvent(event.Kind) || event.Kind == "session.state_changed") && !privateEventSessionValid(authenticator, cookie, subscription, observer) {
				_ = connection.Close(websocket.StatusPolicyViolation, "session is no longer valid")
				return
			}
			writeContext, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			if subscription.Supports("flow_tracing_v1") {
				event = hub.Correlate(writeContext, subscription.AccountID(), event)
			}
			err := wsjson.Write(writeContext, connection, event)
			cancel()
			if err != nil {
				return
			}
			if latencyObserver, ok := observer.(interface{ ObserveRealtimeEventDeliveryLatency(time.Duration) }); ok && !event.OccurredAt.IsZero() {
				if latency := time.Since(event.OccurredAt); latency >= 0 {
					latencyObserver.ObserveRealtimeEventDeliveryLatency(latency)
				}
			}
		case <-overflowed:
			writeContext, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			ok := writeEvent(writeContext, connection, newID, now, "connection.resync_required", map[string]any{"reason": "event_overflow"})
			if ok && hub != nil {
				ok = writeEvent(writeContext, connection, newID, now, "presence.snapshot", map[string]any{"online_user_ids": hub.OnlineAccounts()})
			}
			cancel()
			if !ok {
				return
			}
			subscription.AcknowledgeOverflow()
		}
	}
}
