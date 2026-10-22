package starttracing

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/trace"
	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	"google.golang.org/protobuf/proto"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
)

// Exercise the configured production processor/exporter, not just the predicate.
// The synthetic request count represents 120 ordinary heartbeat completions; it
// intentionally does not claim a ten-minute wall-clock production measurement.
func TestOTLPExportKeepsPresenceChangesAndErrorsWhileHTTPAggregatesRemain(t *testing.T) {
	var mu sync.Mutex
	var exported collectortrace.ExportTraceServiceRequest
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var batch collectortrace.ExportTraceServiceRequest
		if err := proto.Unmarshal(body, &batch); err != nil {
			w.WriteHeader(400)
			return
		}
		mu.Lock()
		exported.ResourceSpans = append(exported.ResourceSpans, batch.ResourceSpans...)
		mu.Unlock()
		w.WriteHeader(200)
	}))
	defer server.Close()
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
	t.Setenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", server.URL)
	t.Setenv("OTEL_TRACES_SAMPLER", "always_on")
	t.Setenv("OTEL_INGEST_AUTH", "")
	oldProvider, oldPropagator := otel.GetTracerProvider(), otel.GetTextMapPropagator()
	defer func() { otel.SetTracerProvider(oldProvider); otel.SetTextMapPropagator(oldPropagator) }()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	shutdown, err := Start(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer shutdown(ctx)
	count := 0
	mux := http.NewServeMux()
	mux.HandleFunc("PUT /api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}", func(w http.ResponseWriter, r *http.Request) {
		count++
		if count == 1 {
			trace.SpanFromContext(r.Context()).AddEvent("app.screen.viewer.started")
		}
		if count == 122 {
			w.WriteHeader(503)
			return
		}
		w.WriteHeader(204)
	})
	recorder := httpmetrics.New()
	handler := recorder.Middleware(tracehttp.Middleware(otel.Tracer("test-presence"), mux, mux), mux)
	for i := 0; i < 122; i++ {
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, httptest.NewRequest("PUT", "/api/v1/voice/leases/private-viewer/screen-viewers/private-owner?token=private-token", nil))
		if i == 121 && response.Code != 503 {
			t.Fatal("product failure response changed")
		}
	}
	if err := shutdown(ctx); err != nil {
		t.Fatal(err)
	}
	mu.Lock()
	defer mu.Unlock()
	spans := 0
	events := 0
	failures := 0
	for _, r := range exported.ResourceSpans {
		for _, scope := range r.ScopeSpans {
			for _, span := range scope.Spans {
				spans++
				events += len(span.Events)
				for _, a := range span.Attributes {
					if a.Key == "http.response.status_code" && a.Value.GetIntValue() == 503 {
						failures++
					}
				}
			}
		}
	}
	if spans != 2 || events != 1 || failures != 1 {
		t.Fatalf("exported spans=%d events=%d failures=%d", spans, events, failures)
	}
	encoded, _ := proto.Marshal(&exported)
	for _, private := range []string{"private-viewer", "private-owner", "private-token"} {
		if strings.Contains(string(encoded), private) {
			t.Fatal("raw private value exported")
		}
	}
	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest("GET", "/metrics", nil))
	for _, want := range []string{
		`voice_platform_api_requests_total{method="PUT",route="/api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}",status="204"} 121`,
		`voice_platform_api_requests_total{method="PUT",route="/api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}",status="503"} 1`,
		`voice_platform_api_request_duration_seconds_count{method="PUT",route="/api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}",status="204"} 121`,
	} {
		if !strings.Contains(scrape.Body.String(), want) {
			t.Fatal("HTTP aggregate missing after span suppression")
		}
	}
	t.Logf("synthetic OTLP export: 122 completed requests; 120 routine spans omitted, 1 real transition and 1 failure retained; payload bytes=%d", len(encoded))
}
