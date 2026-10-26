package centralexport

import (
	"testing"
)

func TestPublicEnrollmentOriginCannotCarrySecretsOrPrivateIP(t *testing.T) {
	for _, value := range []string{"http://example.com", "https://127.0.0.1", "https://user:password@example.com", "https://example.com/path", "https://example.com?token=value", "https://example.com#secret"} {
		if Endpoint(value) == nil {
			t.Fatal("unsafe origin accepted")
		}
	}
	if Endpoint("https://telemetry.example.org") != nil {
		t.Fatal("public origin rejected")
	}
}
