package centralprojection

import (
	"bytes"
	trace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	common "go.opentelemetry.io/proto/otlp/common/v1"
	resource "go.opentelemetry.io/proto/otlp/resource/v1"
	spans "go.opentelemetry.io/proto/otlp/trace/v1"
	"google.golang.org/protobuf/proto"
	"testing"
	"time"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestProjectionDropsPrivateEverywhereAndScopesCorrelation(t *testing.T) {
	a, _ := identity.New()
	b, _ := identity.New()
	now := uint64(time.Now().UnixNano())
	in := &trace.ExportTraceServiceRequest{ResourceSpans: []*spans.ResourceSpans{{Resource: &resource.Resource{Attributes: []*common.KeyValue{String("service.name", "boohtacord-web"), String("user.name", "PRIVATE")}}, ScopeSpans: []*spans.ScopeSpans{{Spans: []*spans.Span{{Name: "api.request", TraceId: bytes.Repeat([]byte{1}, 16), SpanId: bytes.Repeat([]byte{2}, 8), StartTimeUnixNano: now - 1000, EndTimeUnixNano: now, Attributes: []*common.KeyValue{String("user.id", "account"), String("session.id", "session"), String("user.name", "PRIVATE"), String("http.url", "PRIVATE")}, Events: []*spans.Span_Event{{Name: "PRIVATE"}}, Status: &spans.Status{Message: "PRIVATE"}}}}}}}}
	raw, _ := proto.Marshal(in)
	x, err := Traces(raw, a)
	if err != nil {
		t.Fatal(err)
	}
	y, err := Traces(raw, b)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(x, []byte("PRIVATE")) || bytes.Contains(x, []byte("account")) || bytes.Equal(x, y) {
		t.Fatal("private data or mixed identity")
	}
	var clean trace.ExportTraceServiceRequest
	proto.Unmarshal(x, &clean)
	span := clean.ResourceSpans[0].ScopeSpans[0].Spans[0]
	if !bytes.Equal(span.TraceId, in.ResourceSpans[0].ScopeSpans[0].Spans[0].TraceId) {
		t.Fatal("trace causality changed")
	}
	if len(span.Events) != 0 || span.Status.Message != "" {
		t.Fatal("free text leaked")
	}
}
