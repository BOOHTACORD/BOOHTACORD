package connectsession

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/coder/websocket"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	"voice-platform/backend/internal/realtime/heartbeat"
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
)

func streamEvents(connection *websocket.Conn, authenticator sessionapi.Authenticator, cookie *http.Cookie, subscription *eventhub.Subscription, hub *eventhub.Hub, newID Identifier, now Clock, observer ConnectionObserver, replayedIDs map[replayKey]struct{}, maintenance *observestate.Subscription, roster RosterStream, maxRosterBytes int) {
	activity, inactivity, readClosed, stopRead := startActivityReader(connection, subscription != nil)
	defer stopRead()
	heartbeats, stopHeartbeat := heartbeat.Ticks(connection)
	defer stopHeartbeat()
	events, overflowed := subscriptionChannels(subscription)
	maintenanceEvents := maintenanceChannel(maintenance)
	rosterEvents := rosterEventsOrNil(roster)
	var checks <-chan rosterCheckResult
	var cancelCheck context.CancelFunc
	var version uint64
	defer cancelPendingCheck(&cancelCheck)
	firstMaintenance := true
	for {
		select {
		case <-readClosed:
			return
		case <-activity:
			hub.ReportActivity(subscription, time.Now())
		case <-inactivity:
			hub.ReportInactive(subscription, time.Now())
		case <-heartbeats:
			if !writeHeartbeat(connection, newID, now) {
				return
			}
		case delivery, ok := <-rosterEvents:
			if !ok {
				return
			}
			if cancelCheck != nil {
				cancelCheck()
				checks, cancelCheck = nil, nil
			}
			if delivery.SessionInvalid || delivery.Unavailable {
				if !writeRoster(connection, roster, delivery, maxRosterBytes, newID, now) {
					return
				}
				version++
			} else if !roster.Current(delivery.State) {
				if !roster.RequestRefresh() {
					return
				}
			} else {
				checks, cancelCheck = startRosterCheck(roster, delivery, version)
			}
		case result := <-checks:
			cancelCheck()
			checks, cancelCheck = nil, nil
			if errors.Is(result.err, guard.ErrSession) {
				_ = writeRoster(connection, roster, RosterDelivery{SessionInvalid: true}, maxRosterBytes, newID, now)
				return
			}
			if errors.Is(result.err, guard.ErrStale) || !roster.Current(result.delivery.State) {
				if !roster.RequestRefresh() {
					return
				}
				continue
			}
			if result.err != nil {
				if !writeRoster(connection, roster, RosterDelivery{Unavailable: true}, maxRosterBytes, newID, now) {
					return
				}
				version++
				continue
			}
			if result.version == version {
				consumed, ok := writePendingHubEvent(events, connection, authenticator, cookie, subscription, hub, observer, replayedIDs)
				if !ok {
					return
				}
				if consumed {
					version++
				}
			}
			if result.version != version {
				checks, cancelCheck = startRosterCheck(roster, result.delivery, version)
				continue
			}
			if !writeRoster(connection, roster, result.delivery, maxRosterBytes, newID, now) {
				return
			}
			version++
		case state, ok := <-maintenanceEvents:
			if !ok || !writeMaintenance(connection, state, firstMaintenance, newID, now) {
				return
			}
			firstMaintenance = false
			version++
		case event := <-events:
			if !writeHubEvent(connection, authenticator, cookie, subscription, hub, observer, replayedIDs, event) {
				return
			}
			version++
		case <-overflowed:
			if !writeOverflow(connection, subscription, hub, newID, now) {
				return
			}
			version++
		}
	}
}
