package connectsession

import (
	"net/http"
	"time"

	"github.com/google/uuid"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func connectionDefaults(now Clock, newID Identifier) (Clock, Identifier) {
	if now == nil {
		now = time.Now
	}
	if newID == nil {
		newID = uuid.NewString
	}
	return now, newID
}

func observeConnection(observer ConnectionObserver) func() {
	if observer == nil {
		return func() {}
	}
	observer.RealtimeConnectionOpened()
	return observer.RealtimeConnectionClosed
}

func NewHandler(authenticator sessionapi.Authenticator, interval time.Duration, now Clock, newID Identifier, observer ConnectionObserver) http.Handler {
	return NewHandlerWithAdmission(authenticator, interval, now, newID, observer, nil, nil)
}

func NewHandlerWithEvents(authenticator sessionapi.Authenticator, interval time.Duration, now Clock, newID Identifier, observer ConnectionObserver, events *eventhub.Hub) http.Handler {
	return NewHandlerWithAdmission(authenticator, interval, now, newID, observer, events, nil)
}

func NewHandlerWithAdmission(authenticator sessionapi.Authenticator, interval time.Duration, now Clock, newID Identifier, observer ConnectionObserver, events *eventhub.Hub, admission Admission) http.Handler {
	return NewHandlerWithMaintenance(authenticator, interval, now, newID, observer, events, admission, nil)
}

func NewHandlerWithMaintenance(authenticator sessionapi.Authenticator, interval time.Duration, now Clock, newID Identifier, observer ConnectionObserver, events *eventhub.Hub, admission Admission, maintenance *observestate.Observer) http.Handler {
	return NewHandlerWithRoster(authenticator, interval, now, newID, observer, events, admission, maintenance, nil, 0)
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
