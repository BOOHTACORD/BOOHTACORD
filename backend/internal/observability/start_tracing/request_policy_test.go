package starttracing

import (
	"context"
	"testing"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"go.opentelemetry.io/otel/trace"
)

func TestRequestPolicySuppressesOnlySuccessfulRoutinePresence(t *testing.T) {
	const poll = "GET /api/v1/voice/leases/{ownerLeaseID}/screen-viewers"
	const heartbeat = "PUT /api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}"
	cases := []struct {
		name, route  string
		status       int
		event, flow  string
		failed, keep bool
	}{
		{name: "owner poll", route: poll, status: 200},
		{name: "viewer poll", route: "GET /api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}", status: 200},
		{name: "heartbeat", route: heartbeat, status: 204},
		{name: "preauth rejection", route: poll, status: 401, keep: true},
		{name: "poll failure", route: poll, status: 503, keep: true},
		{name: "heartbeat timeout", route: heartbeat, status: 200, failed: true, keep: true},
		{name: "presence started", route: heartbeat, status: 204, event: "app.screen.viewer.started", keep: true},
		{name: "flow correlated", route: heartbeat, status: 204, flow: "11111111111111111111111111111111", keep: true},
		{name: "stop", route: "DELETE /api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}", status: 204, keep: true},
		{name: "short unauthenticated action", route: "POST /api/v1/auth/login", status: 204, keep: true},
		{name: "legacy route missing", status: 200, keep: true},
		{name: "missing outcome", route: poll, keep: true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			recorder := tracetest.NewSpanRecorder()
			provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(requestProcessor{next: recorder}))
			defer provider.Shutdown(context.Background())
			_, span := provider.Tracer("policy-test").Start(context.Background(), tc.route, trace.WithSpanKind(trace.SpanKindServer), trace.WithAttributes(attribute.String("http.route", tc.route), attribute.Int("http.response.status_code", tc.status)))
			if tc.event != "" {
				span.AddEvent(tc.event)
			}
			if tc.flow != "" {
				span.SetAttributes(attribute.String("app.flow.id", tc.flow))
			}
			if tc.failed {
				span.SetStatus(codes.Error, "deadline")
			}
			span.End()
			if got := len(recorder.Ended()) == 1; got != tc.keep {
				t.Fatalf("exported=%t want=%t", got, tc.keep)
			}
		})
	}
}

func TestRequestPolicyKeepsClientAndInternalSpans(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(requestProcessor{next: recorder}))
	defer provider.Shutdown(context.Background())
	for _, kind := range []trace.SpanKind{trace.SpanKindClient, trace.SpanKindInternal} {
		_, span := provider.Tracer("test").Start(context.Background(), "single sample", trace.WithSpanKind(kind), trace.WithAttributes(attribute.String("http.route", "GET /api/v1/voice/leases/{ownerLeaseID}/screen-viewers"), attribute.Int("http.response.status_code", 200)))
		span.End()
	}
	if len(recorder.Ended()) != 2 {
		t.Fatal("policy discarded a non-server span")
	}
}
