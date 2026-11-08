package connectsession

import (
	"net/http"
	"time"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func NewHandler(authenticator sessionapi.Authenticator, interval time.Duration, now Clock, newID Identifier, observer ConnectionObserver) http.Handler {
	return NewHandlerWithAdmission(authenticator, interval, now, newID, observer, nil, nil)
}

func NewHandlerWithEvents(authenticator sessionapi.Authenticator, interval time.Duration, now Clock, newID Identifier, observer ConnectionObserver, events *eventhub.Hub) http.Handler {
	return NewHandlerWithAdmission(authenticator, interval, now, newID, observer, events, nil)
}

func NewHandlerWithAdmission(authenticator sessionapi.Authenticator, interval time.Duration, now Clock, newID Identifier, observer ConnectionObserver, events *eventhub.Hub, admission Admission) http.Handler {
	return NewHandlerWithMaintenance(authenticator, interval, now, newID, observer, events, admission, nil)
}

func subscribeMaintenance(request *http.Request, observer *observestate.Observer) *observestate.Subscription {
	if observer == nil {
		return nil
	}
	for _, capability := range requestedCapabilities(request) {
		if capability == "maintenance_v1" {
			return observer.Subscribe()
		}
	}
	return nil
}
