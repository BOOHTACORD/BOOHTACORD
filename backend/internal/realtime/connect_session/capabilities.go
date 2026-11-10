package connectsession

import (
	"net/http"
	"strings"
)

func requestedCapabilities(request *http.Request) []string {
	values := strings.Split(request.URL.Query().Get("capabilities"), ",")
	result := make([]string, 0, len(values))
	for _, value := range values {
		if value = strings.TrimSpace(value); value != "" {
			result = append(result, value)
		}
	}
	return result
}

// capabilityClass records claimed features only; it is never an access decision.
func capabilityClass(request *http.Request) string {
	var roster, maintenance bool
	for _, value := range requestedCapabilities(request) {
		switch value {
		case "voice_roster_v1":
			roster = true
		case "maintenance_v1":
			maintenance = true
		}
	}
	switch {
	case roster && maintenance:
		return "both"
	case roster:
		return "roster_only"
	case maintenance:
		return "maintenance_only"
	default:
		return "neither"
	}
}

type capabilityMetricsObserver interface {
	RealtimeCapabilityOpened(string)
	RealtimeCapabilityClosed(string)
}

func observeCapabilityConnection(observer ConnectionObserver, request *http.Request) func() {
	metrics, ok := observer.(capabilityMetricsObserver)
	if !ok {
		return func() {}
	}
	class := capabilityClass(request)
	metrics.RealtimeCapabilityOpened(class)
	return func() { metrics.RealtimeCapabilityClosed(class) }
}
