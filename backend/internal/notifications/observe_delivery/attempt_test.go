package observedelivery_test

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/codes"
	sdk "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"strings"
	"testing"
	observe "voice-platform/backend/internal/notifications/observe_delivery"
)

func TestAttemptTraceHasActionableErrorAndOnlyBoundedAttributes(t *testing.T) {
	previous := otel.GetTracerProvider()
	defer otel.SetTracerProvider(previous)
	recorder := tracetest.NewSpanRecorder()
	provider := sdk.NewTracerProvider(sdk.WithSpanProcessor(recorder))
	defer provider.Shutdown(context.Background())
	otel.SetTracerProvider(provider)
	_, finish := observe.Attempt(context.Background(), "web_push")
	finish("retry", "configuration_error")
	_, untrusted := observe.Attempt(context.Background(), "https://private-endpoint.invalid/token")
	untrusted("private-message", "private-reference")
	spans := recorder.Ended()
	if len(spans) != 2 || spans[0].Status().Code != codes.Error || spans[0].Status().Description != "configuration_error" {
		t.Fatal("missing actionable error span")
	}
	for _, span := range spans {
		if span.Name() != "notification.attempt" {
			t.Fatal(span.Name())
		}
		for _, a := range span.Attributes() {
			if strings.Contains(a.Value.AsString(), "private") {
				t.Fatal("private data in trace", a.Key)
			}
		}
	}
}
