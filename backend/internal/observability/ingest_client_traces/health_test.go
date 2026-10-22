package ingestclienttraces

import (
	"bytes"
	"context"
	"crypto/sha256"
	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"google.golang.org/protobuf/proto"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"

	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
)

func TestRelayHealthKeepsSourceFailureSeparateFromOtherAcceptance(t *testing.T) {
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	defer provider.Shutdown(context.Background())
	meter := provider.Meter("test-relay-source")
	oldRequests, oldLatency, oldFreshness, oldRecords := relayRequests, relayLatency, relayFreshness, relayRecords
	defer func() {
		relayRequests, relayLatency, relayFreshness, relayRecords = oldRequests, oldLatency, oldFreshness, oldRecords
	}()
	relayRequests, _ = meter.Int64Counter("boohtacord.telemetry.relay.requests")
	relayLatency, _ = meter.Float64Histogram("boohtacord.telemetry.relay.duration", metric.WithUnit("s"))
	relayFreshness, _ = meter.Int64Gauge("boohtacord.telemetry.relay.last_accept", metric.WithUnit("s"))
	relayRecords, _ = meter.Int64Counter("boohtacord.telemetry.relay.records")
	handler := withRelayHealth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Client-Platform") == "web" {
			observeBatch(r.Context(), batchResult{Accepted: 2})
			accepted(w, batchResult{Accepted: 2})
			return
		}
		observeBatch(r.Context(), batchResult{Rejected: 1, Reason: "session_mismatch"})
		w.WriteHeader(503)
	}))
	for _, platform := range []string{"web", "ios", "private-username"} {
		request := httptest.NewRequest("POST", "/api/v1/telemetry/traces", nil)
		request.Header.Set("X-Client-Platform", platform)
		handler.ServeHTTP(httptest.NewRecorder(), request)
	}
	var data metricdata.ResourceMetrics
	if err := reader.Collect(context.Background(), &data); err != nil {
		t.Fatal(err)
	}
	observed := map[string]map[string]int64{}
	for _, scope := range data.ScopeMetrics {
		for _, m := range scope.Metrics {
			values := map[string]int64{}
			switch v := m.Data.(type) {
			case metricdata.Sum[int64]:
				for _, p := range v.DataPoints {
					platform, _ := p.Attributes.Value("platform")
					values[platform.AsString()] += p.Value
				}
			case metricdata.Gauge[int64]:
				for _, p := range v.DataPoints {
					platform, _ := p.Attributes.Value("platform")
					values[platform.AsString()] = p.Value
				}
			}
			observed[m.Name] = values
		}
	}
	for _, name := range []string{"boohtacord.telemetry.relay.requests", "boohtacord.telemetry.relay.records"} {
		if len(observed[name]) != 3 || observed[name]["ios"] == 0 || observed[name]["unknown"] == 0 {
			t.Fatalf("source lost: %s %v", name, observed[name])
		}
	}
	fresh := observed["boohtacord.telemetry.relay.last_accept"]
	if len(fresh) != 1 || fresh["web"] == 0 {
		t.Fatal("failed source received false last accepted timestamp")
	}
}

func TestRelaySeparatesSanitizerAndCollectorRejections(t *testing.T) {
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	defer provider.Shutdown(context.Background())
	old := relayRecords
	relayRecords, _ = provider.Meter("test-mixed-rejections").Int64Counter("boohtacord.telemetry.relay.records")
	defer func() { relayRecords = old }()
	reply, _ := proto.Marshal(&collectortrace.ExportTraceServiceResponse{PartialSuccess: &collectortrace.ExportTracePartialSuccess{RejectedSpans: 1}})
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write(reply) }))
	defer upstream.Close()
	first, second, unsupported := flowSpan(), flowSpan(), flowSpan()
	second.SpanId = bytes.Repeat([]byte{3}, 8)
	unsupported.SpanId = bytes.Repeat([]byte{4}, 8)
	unsupported.Name = "not.supported"
	batch, _ := proto.Marshal(flowBatch(first, second, unsupported))
	request := httptest.NewRequest("POST", "/api/v1/telemetry/traces", bytes.NewReader(batch))
	request.Header.Set("Content-Type", "application/x-protobuf")
	request.Header.Set("X-Client-Platform", "ios")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "verified", SessionDigest: sha256.Sum256([]byte("session"))}))
	// The batch must use the authenticated diagnostic ID, never an arbitrary claim.
	id, _ := diagnosticIdentity(request)
	for _, span := range []*tracepb.Span{first, second, unsupported} {
		for _, a := range span.Attributes {
			if a.Key == "session.id" {
				a.Value = &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: id}}
			}
		}
	}
	batch, _ = proto.Marshal(flowBatch(first, second, unsupported))
	request.Body = io.NopCloser(bytes.NewReader(batch))
	response := httptest.NewRecorder()
	NewHandler(upstream.URL, "Basic synthetic", upstream.Client()).ServeHTTP(response, request)
	if response.Code != 202 || response.Header().Get("X-Telemetry-Accepted") != "1" || response.Header().Get("X-Telemetry-Rejected") != "2" {
		t.Fatal("wrong partial response totals")
	}
	var data metricdata.ResourceMetrics
	reader.Collect(context.Background(), &data)
	got := map[string]int64{}
	for _, scope := range data.ScopeMetrics {
		for _, m := range scope.Metrics {
			if sum, ok := m.Data.(metricdata.Sum[int64]); ok {
				for _, p := range sum.DataPoints {
					reason, _ := p.Attributes.Value("reason")
					got[reason.AsString()] += p.Value
				}
			}
		}
	}
	if got["unsupported"] != 1 || got["collector_rejected"] != 1 || got["none"] != 1 {
		t.Fatalf("rejection reasons mixed: %v", got)
	}
}

func TestRelayHealthRecordsPanicAsFailureAndRepanics(t *testing.T) {
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	defer provider.Shutdown(context.Background())
	old := relayRequests
	defer func() { relayRequests = old }()
	relayRequests, _ = provider.Meter("panic-health").Int64Counter("boohtacord.telemetry.relay.requests")
	handler := withRelayHealth(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { panic("synthetic") }))
	didPanic := false
	func() {
		defer func() { didPanic = recover() != nil }()
		handler.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("POST", "/synthetic", nil))
	}()
	if !didPanic {
		t.Fatal("middleware swallowed panic")
	}
	var data metricdata.ResourceMetrics
	reader.Collect(context.Background(), &data)
	found := false
	for _, scope := range data.ScopeMetrics {
		for _, m := range scope.Metrics {
			if sum, ok := m.Data.(metricdata.Sum[int64]); ok {
				for _, point := range sum.DataPoints {
					status, _ := point.Attributes.Value("http.response.status_code")
					if status.AsInt64() == 500 && point.Value == 1 {
						found = true
					}
				}
			}
		}
	}
	if !found {
		t.Fatal("panic completion reported as successful request")
	}
}
