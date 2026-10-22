package reportscreenapi

import (
	"context"
	"crypto/sha256"
	"net/http"
	"testing"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	bindflow "voice-platform/backend/internal/observability/bind_flow"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

func TestMediaSamplePreservesVisitWithoutOverridingVerifiedLease(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	old := otel.GetTracerProvider()
	otel.SetTracerProvider(provider)
	defer func() { otel.SetTracerProvider(old); provider.Shutdown(context.Background()) }()
	ctx := sessionapi.WithPrincipal(context.Background(), auth.Principal{AccountID: "verified", SessionDigest: sha256.Sum256([]byte("private"))})
	headers := http.Header{"X-Telemetry-Session": {"11111111111111111111111111111111"}, "X-App-Visit": {"22222222222222222222222222222222"}, "X-App-Flow": {"33333333333333333333333333333333"}, "X-App-Flow-Name": {"screen.view"}, "X-App-Attempt": {"2"}, "X-App-Media-Session": {"44444444444444444444444444444444"}}
	ctx = bindflow.Bind(ctx, headers, "11111111111111111111111111111111")
	recordMediaSample(ctx, httpmetrics.ClientScreenReport{Platform: "macos_native", Direction: "receiver", State: "playing"}, "55555555555555555555555555555555")
	attrs := map[attribute.Key]attribute.Value{}
	for _, a := range recorder.Ended()[0].Attributes() {
		attrs[a.Key] = a.Value
	}
	for key, want := range map[attribute.Key]string{"client.platform": "macos", "app.visit.id": "22222222222222222222222222222222", "app.flow.id": "33333333333333333333333333333333", "app.media.session.id": "55555555555555555555555555555555", "app.provenance": "client_observed"} {
		if attrs[key].AsString() != want {
			t.Fatalf("wrong %s", key)
		}
	}
	if attrs["app.flow.attempt"].AsInt64() != 2 {
		t.Fatal("attempt absent")
	}
}

func TestMediaSampleLegacyPlatformDoesNotInventNativeOS(t *testing.T) {
	for input, want := range map[string]string{"desktop_web": "web", "ios_web": "web", "android_web": "web", "android_native": "android", "ios_native": "ios", "windows_native": "windows", "macos_native": "macos", "desktop_native": "", "private": ""} {
		if got := sampleClientPlatform(input); got != want {
			t.Fatalf("%s mapped to %s want %s", input, got, want)
		}
	}
}
