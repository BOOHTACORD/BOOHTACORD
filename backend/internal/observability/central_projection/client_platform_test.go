package centralprojection

import (
	common "go.opentelemetry.io/proto/otlp/common/v1"
	resource "go.opentelemetry.io/proto/otlp/resource/v1"
	"testing"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestClientPlatformAndVersionAreBoundedAcrossCentralProjection(t *testing.T) {
	installation, _ := identity.New()
	for input, want := range map[string]string{"web": "web", "macos": "macos", "windows": "windows", "ios": "ios", "android": "android", "private": "", "boohtacord-api": ""} {
		result, err := Resource(&resource.Resource{Attributes: []*common.KeyValue{String("service.name", "boohtacord-api"), String("client.platform", input)}}, installation)
		if err != nil {
			t.Fatal(err)
		}
		found := ""
		for _, a := range result.Attributes {
			if a.Key == "client.platform" {
				found = a.Value.GetStringValue()
			}
		}
		if found != want {
			t.Fatalf("resource client platform %s: %s", input, found)
		}
		attrs := attributes([]*common.KeyValue{String("client.platform", input)}, installation)
		if (len(attrs) == 1) != (want != "") {
			t.Fatal("span platform escaped enum")
		}
	}
	for input, kept := range map[string]bool{"1.0.47": true, "1.0.47+82": true, "private-account": false, "1.0.47+private": false} {
		attrs := attributes([]*common.KeyValue{String("app.client.version", input)}, installation)
		if (len(attrs) == 1) != kept {
			t.Fatalf("version %s kept=%t", input, len(attrs) == 1)
		}
	}
}

func TestRelaySourceAndRejectionReasonRemainDistinctAfterProjection(t *testing.T) {
	installation, _ := identity.New()
	for _, reason := range []string{"unsupported", "malformed", "size", "session_mismatch", "collector_rejected"} {
		attrs := MetricLabels([]*common.KeyValue{String("platform", "ios"), String("reason", reason)}, installation, "boohtacord-api", "")
		found := map[string]string{}
		for _, a := range attrs {
			found[a.Key] = a.Value.GetStringValue()
		}
		if found["reason"] != reason || found["platform"] != "ios" {
			t.Fatal("source/reason collapsed during central projection")
		}
	}
}
