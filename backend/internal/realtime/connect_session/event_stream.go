package connectsession

import (
	"context"
	"errors"
	"net/http"

	"github.com/coder/websocket"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
)

func streamEvents(connection *websocket.Conn, authenticator sessionapi.Authenticator, cookie *http.Cookie, subscription *eventhub.Subscription, hub *eventhub.Hub, newID Identifier, now Clock, observer ConnectionObserver, replayedIDs map[replayKey]struct{}, maintenance *observestate.Subscription, roster RosterStream, maxRosterBytes int) {
	closed := connection.CloseRead(context.Background()).Done()
	var events <-chan eventhub.Event
	var overflowed <-chan struct{}
	var maintenanceEvents <-chan observestate.State
	var rosterEvents <-chan RosterDelivery
	var checks <-chan rosterCheckResult
	var cancelCheck context.CancelFunc
	var version uint64
	defer func() {
		if cancelCheck != nil {
			cancelCheck()
		}
	}()
	if roster != nil {
		rosterEvents = roster.Events()
	}
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
				select {
				case event := <-events:
					if !writeHubEvent(connection, authenticator, cookie, subscription, hub, observer, replayedIDs, event) {
						return
					}
					version++
				default:
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
