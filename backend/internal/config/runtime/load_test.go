package runtimeconfig

import "testing"

func environment() map[string]string {
	return map[string]string{
		"PUBLIC_ORIGIN": "https://example.test", "ATTACHMENTS_DIRECTORY": "/attachments",
		"LIVEKIT_PUBLIC_WS_URL": "wss://example.test", "LIVEKIT_PRIVATE_HTTP_URL": "http://livekit:7880",
		"LIVEKIT_API_KEY": "test-key", "LIVEKIT_API_SECRET": "test-secret",
	}
}

func TestLoadReturnsValidationErrorsWithoutExiting(t *testing.T) {
	for _, name := range []string{"PUBLIC_ORIGIN", "ATTACHMENTS_DIRECTORY", "LIVEKIT_API_KEY", "LIVEKIT_API_SECRET", "LIVEKIT_PUBLIC_WS_URL", "LIVEKIT_PRIVATE_HTTP_URL"} {
		t.Run(name, func(t *testing.T) {
			values := environment()
			delete(values, name)
			if _, err := Load(func(key string) string { return values[key] }); err == nil {
				t.Fatal("invalid configuration accepted")
			}
		})
	}
}

func TestDefaultsAndExplicitTraceEndpointPreservePrecedence(t *testing.T) {
	values := environment()
	values["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://collector:4318/"
	configuration, err := Load(func(key string) string { return values[key] })
	if err != nil {
		t.Fatal(err)
	}
	if configuration.RegistrationLimiter == nil || configuration.LoginLimiter == nil || configuration.LoginAdmission == nil || configuration.PasswordResetLimiter == nil || configuration.UploadLimiter == nil || configuration.UploadAccountLimiter == nil || configuration.UploadDeploymentLimiter == nil || configuration.TelemetryLimiter == nil || configuration.RealtimeConnectionLimiter == nil || configuration.UploadAdmissionLimiter == nil {
		t.Fatal("admission limiters were not configured")
	}
	if configuration.Address != ":8080" || configuration.TelemetryEndpoint != "http://collector:4318/v1/traces" {
		t.Fatal("defaults changed")
	}
	if configuration.ClientUpdateCatalogPath == "" || len(configuration.ClientUpdateAllowedHosts) != 1 || configuration.ClientUpdateAllowedHosts[0] != "example.test" {
		t.Fatal("client update defaults are invalid")
	}
	values["API_ADDR"] = "127.0.0.1:9999"
	values["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"] = "http://specific:4318/custom"
	configuration, err = Load(func(key string) string { return values[key] })
	if err != nil || configuration.Address != values["API_ADDR"] || configuration.TelemetryEndpoint != values["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"] {
		t.Fatal("explicit configuration precedence changed")
	}
}

func TestLoadRejectsInvalidTrustedProxyCIDR(t *testing.T) {
	values := environment()
	values["TRUSTED_PROXY_CIDRS"] = "not-a-cidr"
	if _, err := Load(func(key string) string { return values[key] }); err == nil {
		t.Fatal("invalid trusted proxy configuration accepted")
	}
}

func TestLoginSourceLimitMatchesADR003(t *testing.T) {
	values := environment()
	configuration, err := Load(func(key string) string { return values[key] })
	if err != nil {
		t.Fatal(err)
	}
	for attempt := 1; attempt <= 10; attempt++ {
		if _, allowed := configuration.LoginLimiter.Allow("198.51.100.20"); !allowed {
			t.Fatalf("login attempt %d was rejected before the ADR-003 limit", attempt)
		}
	}
	if _, allowed := configuration.LoginLimiter.Allow("198.51.100.20"); allowed {
		t.Fatal("11th login attempt from one source was allowed")
	}
}
