package observehttprequests

import "testing"

func TestRetiredStreamPathsHaveNoServiceOperation(t *testing.T) {
	for _, path := range []string{"/api/v1/maintenance/events", "/api/v1/voice/rosters/events"} {
		if Operation(path) != "" {
			t.Fatalf("retired path still has a service operation: %s", path)
		}
	}
}
