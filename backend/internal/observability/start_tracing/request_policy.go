package starttracing

import (
	"context"

	"go.opentelemetry.io/otel/codes"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
)

// requestProcessor makes an outcome-aware export decision for the fixed presence
// polling routes. It deliberately runs after recording: authentication attributes,
// real state transitions, errors and parent-based sampling remain intact. It does
// not classify a trace by duration, identity, number of children or span name.
// HTTP aggregates are recorded independently of this export decision.
type requestProcessor struct{ next sdktrace.SpanProcessor }

func (p requestProcessor) OnStart(ctx context.Context, span sdktrace.ReadWriteSpan) {
	p.next.OnStart(ctx, span)
}
func (p requestProcessor) OnEnd(span sdktrace.ReadOnlySpan) {
	if routinePresence(span) {
		return
	}
	p.next.OnEnd(span)
}
func (p requestProcessor) Shutdown(ctx context.Context) error   { return p.next.Shutdown(ctx) }
func (p requestProcessor) ForceFlush(ctx context.Context) error { return p.next.ForceFlush(ctx) }

func routinePresence(span sdktrace.ReadOnlySpan) bool {
	if span.SpanKind() != trace.SpanKindServer || span.Status().Code == codes.Error || len(span.Events()) > 0 {
		return false
	}
	var route string
	var status int64
	for _, a := range span.Attributes() {
		switch a.Key {
		case "http.route":
			route = a.Value.AsString()
		case "http.response.status_code":
			status = a.Value.AsInt64()
		case "app.flow.id":
			if a.Value.AsString() != "" {
				return false
			}
		}
	}
	if status < 200 || status >= 300 {
		return false
	}
	switch route {
	case "GET /api/v1/voice/leases/{ownerLeaseID}/screen-viewers",
		"GET /api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}",
		"PUT /api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}":
		return true
	}
	return false
}
