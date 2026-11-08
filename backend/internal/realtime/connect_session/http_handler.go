package connectsession

import (
	"context"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/session"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func NewHandlerWithMaintenance(authenticator sessionapi.Authenticator, revalidationInterval time.Duration, now Clock, newID Identifier, observer ConnectionObserver, events *eventhub.Hub, admission Admission, maintenance *observestate.Observer) http.Handler {
	if now == nil {
		now = time.Now
	}
	if newID == nil {
		newID = uuid.NewString
	}
	revalidationInterval = boundedRevalidationInterval(revalidationInterval)
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writer.WriteHeader(http.StatusInternalServerError)
			return
		}
		if admission != nil {
			release, allowed := admission.TryAcquire(principal.AccountID, principal.SessionDigest)
			if !allowed {
				rejectAdmission(writer, observer)
				return
			}
			defer release()
		}
		cookie, err := request.Cookie(session.CookieName)
		if authenticator != nil && err != nil {
			writer.WriteHeader(http.StatusInternalServerError)
			return
		}
		connection, err := websocket.Accept(writer, request, nil)
		if err != nil {
			return
		}
		defer connection.CloseNow()
		stopMonitor := startSessionMonitor(request.Context(), connection, authenticator, cookie, principal, revalidationInterval, observer)
		defer stopMonitor()
		finishHandshake := beginHandshake(request.Context())
		defer finishHandshake(errHandshakeWrite)
		var subscription *eventhub.Subscription
		if events != nil {
			subscription = events.SubscribeAccountWithCapabilities(principal.AccountID, presenceEvent(principal.AccountID, "online", newID, now), requestedCapabilities(request))
			defer subscription.Close(presenceEvent(principal.AccountID, "offline", newID, now))
		}
		acceptedAt := time.Now()
		if observer != nil {
			observer.RealtimeConnectionOpened()
			defer observer.RealtimeConnectionClosed()
		}
		maintenanceSub := subscribeMaintenance(request, maintenance)
		if maintenanceSub != nil {
			defer maintenanceSub.Close()
		}
		writeContext, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		var replay []eventhub.Event
		var replayReason string
		var replayEpoch string
		if request.URL.Query().Has("after") {
			if !privateEventSessionValid(authenticator, cookie, subscription, observer) && events != nil {
				finishHandshake(errHandshakeSession)
				observeReconnectOutcome(observer, "rejected")
				_ = connection.Close(websocket.StatusPolicyViolation, "session is no longer valid")
				return
			}
			replay, replayReason, replayEpoch = loadReplay(writeContext, events, principal.AccountID, request.URL.Query().Get("after"))
			if replayReason == "" && !events.ContinuityAt(replayEpoch) {
				replay, replayReason = nil, "replay_unavailable"
			}
			if replayReason != "" && !writeEvent(writeContext, connection, newID, now, "connection.resync_required", map[string]any{"reason": replayReason}) {
				return
			}
			if replayReason != "" {
				observeReconnectOutcome(observer, "resync_required")
			}
		}
		if !writeEvent(writeContext, connection, newID, now, "connection.ready", map[string]any{}) {
			return
		}
		replayedIDs := make(map[string]struct{}, len(replay))
		replayComplete := replayReason == ""
		if replayReason == "" && len(replay) > 0 {
			var connectionOpen bool
			connectionOpen, replayComplete = writeAuthorizedReplay(writeContext, connection, authenticator, cookie, subscription, events, replayEpoch, replay, replayedIDs, newID, now, observer)
			if !connectionOpen {
				return
			}
		}
		if replayComplete && request.URL.Query().Has("after") && !events.ContinuityAt(replayEpoch) {
			replayComplete = false
			if !writeEvent(writeContext, connection, newID, now, "connection.resync_required", map[string]any{"reason": "replay_unavailable"}) {
				return
			}
			observeReconnectOutcome(observer, "resync_required")
		}
		if request.URL.Query().Has("after") && replayComplete {
			observeReconnectOutcome(observer, "replayed")
		}
		if events != nil && !writeEvent(writeContext, connection, newID, now, "presence.snapshot", map[string]any{"online_user_ids": events.OnlineAccounts()}) {
			return
		}
		if observer != nil {
			observer.ObserveRealtimeConnectionReady(time.Since(acceptedAt))
		}
		finishHandshake(nil)
		streamEvents(connection, authenticator, cookie, subscription, events, newID, now, observer, replayedIDs, maintenanceSub)
	})
}
