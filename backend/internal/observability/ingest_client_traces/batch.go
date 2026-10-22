package ingestclienttraces

import (
	"bytes"
	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	resourcepb "go.opentelemetry.io/proto/otlp/resource/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"time"
	flow "voice-platform/backend/internal/observability/flow_contract"
)

type batchResult struct {
	Accepted, Rejected int
	Fatal              bool
	Reason             string
}

func sanitizeBatch(input *collectortrace.ExportTraceServiceRequest, platform, sessionID, accountID string) (*collectortrace.ExportTraceServiceRequest, batchResult) {
	result := batchResult{}
	fail := func(reason string) (*collectortrace.ExportTraceServiceRequest, batchResult) {
		result.Fatal = true
		result.Reason = reason
		return nil, result
	}
	if !platforms[platform] || input == nil {
		return fail("malformed")
	}
	spans := []*tracepb.Span{}
	for _, resource := range input.ResourceSpans {
		if resource == nil {
			return fail("malformed")
		}
		for _, scope := range resource.ScopeSpans {
			if scope == nil {
				return fail("malformed")
			}
			spans = append(spans, scope.Spans...)
		}
	}
	if len(spans) == 0 || len(spans) > flow.MaxSpans {
		return fail("size")
	}
	now := time.Now()
	seen := map[string]bool{}
	for _, span := range spans {
		if !validShape(span, now) {
			return fail("malformed")
		}
		key := string(span.TraceId) + string(span.SpanId)
		if seen[key] {
			return fail("malformed")
		}
		seen[key] = true
		if versioned(span) && (sessionID == "" || spanField(span, "session.id") != sessionID) {
			return fail("session_mismatch")
		}
	}
	output := &collectortrace.ExportTraceServiceRequest{ResourceSpans: []*tracepb.ResourceSpans{{
		Resource:   &resourcepb.Resource{Attributes: []*commonpb.KeyValue{flowAttrValue("service.name", "boohtacord-"+platform), flowAttrValue("client.platform", platform)}},
		ScopeSpans: []*tracepb.ScopeSpans{{Scope: &commonpb.InstrumentationScope{Name: "boohtacord-client"}}}}}}
	destination := output.ResourceSpans[0].ScopeSpans[0]
	for _, span := range spans {
		if !flow.Operations[span.Name] {
			result.Rejected++
			continue
		}
		clean := &tracepb.Span{TraceId: bytes.Clone(span.TraceId), SpanId: bytes.Clone(span.SpanId), ParentSpanId: bytes.Clone(span.ParentSpanId),
			Name: span.Name, Kind: tracepb.Span_SPAN_KIND_CLIENT, StartTimeUnixNano: span.StartTimeUnixNano, EndTimeUnixNano: span.EndTimeUnixNano, Flags: span.Flags & 1}
		if span.Status != nil {
			clean.Status = &tracepb.Status{Code: span.Status.Code}
		}
		if versioned(span) {
			attrs, ok := cleanFlow(span, sessionID, accountID)
			if !ok || span.EndTimeUnixNano-span.StartTimeUnixNano > uint64(time.Duration(flow.MaxFlowDurationSeconds)*time.Second) {
				result.Rejected++
				continue
			}
			clean.Attributes = attrs
			if span.Name != "api.request" {
				clean.Kind = tracepb.Span_SPAN_KIND_INTERNAL
			}
		} else {
			cleanLegacy(span, clean, platform)
		}
		destination.Spans = append(destination.Spans, clean)
		result.Accepted++
	}
	for _, clean := range destination.Spans {
		for _, original := range spans {
			if versioned(clean) && bytes.Equal(clean.TraceId, original.TraceId) && bytes.Equal(clean.SpanId, original.SpanId) {
				clean.Links = sameBatchLinks(original, destination.Spans, sessionID)
				break
			}
		}
	}
	result.Reason = "unsupported"
	return output, result
}
