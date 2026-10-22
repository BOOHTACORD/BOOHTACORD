//go:build tracing_runtime

package starttracing

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"google.golang.org/protobuf/proto"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	presence "voice-platform/backend/internal/media/screen_viewer_presence"
	presenceapi "voice-platform/backend/internal/media/screen_viewer_presence/api"
	presencememory "voice-platform/backend/internal/media/screen_viewer_presence/memory"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
)

// This opt-in acceptance test intentionally takes more than ten minutes. It
// compares the original bb51c0d provider's unfiltered SDK batch constructor with
// the candidate processor while holding the real presence handler/store,
// request schedule, sampler, batch limits and downstream stack constant. The
// service authority/authenticator are synthetic; this is not DB/physical-media
// acceptance and not a measurement of production traffic or Tempo disk usage.
func TestRuntimeTenMinutePresencePolicyMeasurement(t *testing.T) {
	if os.Getenv("TRACE_QA_PRESENCE_MEASURE") != "1" {
		t.Skip("explicit ten-minute isolated workload required")
	}
	collector, tempo, metrics := measurementEndpoint(t, "TRACE_QA_COLLECTOR_URL"), measurementEndpoint(t, "TRACE_QA_TEMPO_URL"), measurementEndpoint(t, "TRACE_QA_COLLECTOR_METRICS_URL")
	ctx, cancel := context.WithTimeout(context.Background(), 12*time.Minute)
	defer cancel()
	oldMeter := otel.GetMeterProvider()
	defer otel.SetMeterProvider(oldMeter)
	phases := []*measurementPhase{newMeasurementPhase(t, ctx, collector, "issue513-before", false), newMeasurementPhase(t, ctx, collector, "issue513-after", true)}
	for _, phase := range phases {
		defer phase.close()
	}
	client := &http.Client{Timeout: 3 * time.Second, Transport: &http.Transport{Proxy: nil}}
	started := time.Now()
	const completed = 122
	for i := 0; i < completed; i++ {
		if i > 0 {
			timer := time.NewTimer(time.Until(started.Add(time.Duration(i) * 5 * time.Second)))
			select {
			case <-ctx.Done():
				timer.Stop()
				t.Fatal("measurement timed out")
			case <-timer.C:
			}
		}
		for _, phase := range phases {
			phase.authority.failed.Store(i == completed-1)
			request, err := http.NewRequestWithContext(ctx, "PUT", phase.server.URL+measurementPresencePath, strings.NewReader(`{"track_sid":"TR_synthetic_measurement"}`))
			if err != nil {
				t.Fatal(err)
			}
			request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "synthetic-measurement-session"})
			response, err := client.Do(request)
			if err != nil {
				t.Fatal("presence workload transport failed")
			}
			io.Copy(io.Discard, response.Body)
			response.Body.Close()
			want := 204
			if i == completed-1 {
				want = 503
			}
			if response.StatusCode != want {
				t.Fatalf("unexpected presence status %d", response.StatusCode)
			}
		}
		if i%24 == 0 {
			t.Logf("presence workload completed_pairs=%d elapsed_seconds=%.1f", i+1, time.Since(started).Seconds())
		}
	}
	elapsed := time.Since(started)
	if elapsed < 10*time.Minute {
		t.Fatal("acceptance requires actual ten-minute wall clock")
	}
	for _, phase := range phases {
		phase.authority.failed.Store(false)
		stop, _ := http.NewRequestWithContext(ctx, "DELETE", phase.server.URL+measurementPresencePath+"?track_sid=TR_synthetic_measurement", nil)
		stop.AddCookie(&http.Cookie{Name: session.CookieName, Value: "synthetic-measurement-session"})
		response, err := client.Do(stop)
		if err != nil {
			t.Fatal(err)
		}
		io.Copy(io.Discard, response.Body)
		response.Body.Close()
		if response.StatusCode != 204 {
			t.Fatal("stop request failed")
		}
		// A one-span pre-login 401 must survive without a synthetic user attribution.
		preauth, _ := http.NewRequestWithContext(ctx, "GET", phase.server.URL+measurementPresencePath, nil)
		response, err = client.Do(preauth)
		if err != nil {
			t.Fatal(err)
		}
		io.Copy(io.Discard, response.Body)
		response.Body.Close()
		if response.StatusCode != 401 {
			t.Fatal("preauth failure absent")
		}
		if err := phase.provider.ForceFlush(ctx); err != nil {
			t.Fatal(err)
		}
		var data metricdata.ResourceMetrics
		if err := phase.reader.Collect(ctx, &data); err != nil {
			t.Fatal(err)
		}
		exporter, err := otlpmetrichttp.New(ctx, otlpmetrichttp.WithEndpointURL(collector+"/v1/metrics"), otlpmetrichttp.WithInsecure(), otlpmetrichttp.WithHTTPClient(client))
		if err != nil {
			t.Fatal(err)
		}
		if err := exporter.Export(ctx, &data); err != nil {
			t.Fatal(err)
		}
		exporter.Shutdown(ctx)
		assertMeasurementMetrics(t, phase, &data)
	}
	report := map[string]any{"status": "PASS", "scope": "isolated synthetic presence policy comparison, not production traffic", "baseline_source": "bb51c0d unfiltered NewBatchSpanProcessor constructor", "cadence_seconds": 5, "presence_requests_each": completed, "additional_requests_each": 2, "wall_seconds": elapsed.Seconds(), "started_at": started.UTC().Format(time.RFC3339), "finished_at": time.Now().UTC().Format(time.RFC3339), "sampling": "always_on identical both phases", "bytes_measure": "OTLP HTTP request bodies sent to Collector, excludes transport headers and storage cost", "phases": map[string]any{}}
	details := report["phases"].(map[string]any)
	for _, phase := range phases {
		phase.mu.Lock()
		spans, wireBytes, batches := len(phase.spans), phase.wireBytes, phase.batches
		captured := append([]*tracepb.Span{}, phase.spans...)
		phase.mu.Unlock()
		want := 124
		if phase.filtered {
			want = 4
		}
		if spans != want {
			t.Fatalf("%s span count %d want %d", phase.version, spans, want)
		}
		stored := assertMeasurementStored(t, ctx, client, tempo, phase.version, started, captured, want)
		assertMeasurementPrometheus(t, ctx, client, metrics, phase.version)
		details[phase.version] = map[string]any{"exported_spans": spans, "stored_traces": stored, "otlp_body_bytes": wireBytes, "otlp_batches": batches, "spans_per_minute": float64(spans) / elapsed.Minutes(), "body_bytes_per_minute": float64(wireBytes) / elapsed.Minutes(), "http_aggregate_success": 121, "http_aggregate_failure": 1, "preauth_401_without_user": "PASS", "start_transition_and_stop": "PASS", "status_503": "PASS", "private_metric_labels": "PASS"}
	}
	output := os.Getenv("TRACE_QA_MEASUREMENT_OUTPUT")
	if output != "" {
		encoded, err := json.MarshalIndent(report, "", "  ")
		if err != nil {
			t.Fatal(err)
		}
		if err := os.MkdirAll(filepath.Dir(output), 0700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(output, append(encoded, '\n'), 0600); err != nil {
			t.Fatal(err)
		}
	}
	t.Logf("ten-minute before/after comparison PASS wall_seconds=%.1f; clean report written=%t", elapsed.Seconds(), output != "")
}

const measurementPresencePath = "/api/v1/voice/leases/11111111-1111-4111-8111-111111111111/screen-viewers/22222222-2222-4222-8222-222222222222"

type measurementAuthority struct{ failed atomic.Bool }

func (a *measurementAuthority) AuthorizeViewer(context.Context, presence.Principal, string, string) (string, string, string, error) {
	if a.failed.Load() {
		return "", "", "", presence.ErrUnavailable
	}
	return "synthetic-channel", "synthetic-owner", "synthetic-viewer", nil
}
func (a *measurementAuthority) AuthorizeOwner(context.Context, presence.Principal, string) (string, string, error) {
	return "synthetic-channel", "synthetic-owner", nil
}

type measurementPublication struct{}

func (measurementPublication) CurrentTrack(context.Context, string, string) (string, error) {
	return "TR_synthetic_measurement", nil
}

type measurementAuthenticator struct{}

func (measurementAuthenticator) Authenticate(context.Context, string) (auth.Principal, error) {
	return auth.Principal{AccountID: "33333333-3333-4333-8333-333333333333", SessionDigest: [32]byte{1}, ExpiresAt: time.Now().Add(time.Hour)}, nil
}

type measurementPhase struct {
	version            string
	filtered           bool
	mu                 sync.Mutex
	spans              []*tracepb.Span
	wireBytes, batches int
	authority          *measurementAuthority
	provider           *sdktrace.TracerProvider
	meter              *sdkmetric.MeterProvider
	reader             *sdkmetric.ManualReader
	recorder           *httpmetrics.Recorder
	server, sink       *httptest.Server
	store              *presencememory.Store
}

func newMeasurementPhase(t *testing.T, ctx context.Context, collector, version string, filtered bool) *measurementPhase {
	t.Helper()
	phase := &measurementPhase{version: version, filtered: filtered, authority: &measurementAuthority{}}
	client := &http.Client{Timeout: 3 * time.Second, Transport: &http.Transport{Proxy: nil}}
	phase.sink = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(io.LimitReader(r.Body, 2<<20))
		if err != nil {
			w.WriteHeader(503)
			return
		}
		var batch collectortrace.ExportTraceServiceRequest
		if proto.Unmarshal(body, &batch) != nil {
			w.WriteHeader(400)
			return
		}
		request, err := http.NewRequestWithContext(r.Context(), "POST", collector+"/v1/traces", bytes.NewReader(body))
		if err != nil {
			w.WriteHeader(503)
			return
		}
		request.Header.Set("Content-Type", "application/x-protobuf")
		response, err := client.Do(request)
		if err != nil {
			w.WriteHeader(503)
			return
		}
		reply, _ := io.ReadAll(io.LimitReader(response.Body, 4096))
		response.Body.Close()
		if response.StatusCode == 200 {
			phase.mu.Lock()
			phase.batches++
			phase.wireBytes += len(body)
			for _, resource := range batch.ResourceSpans {
				for _, scope := range resource.ScopeSpans {
					phase.spans = append(phase.spans, scope.Spans...)
				}
			}
			phase.mu.Unlock()
		}
		w.Header().Set("Content-Type", "application/x-protobuf")
		w.WriteHeader(response.StatusCode)
		w.Write(reply)
	}))
	exporter, err := otlptracehttp.New(ctx, otlptracehttp.WithEndpointURL(phase.sink.URL), otlptracehttp.WithInsecure(), otlptracehttp.WithHTTPClient(client))
	if err != nil {
		t.Fatal(err)
	}
	// These are the original reviewed provider's batch limits, unchanged in both.
	var processor sdktrace.SpanProcessor = sdktrace.NewBatchSpanProcessor(exporter, sdktrace.WithMaxQueueSize(128), sdktrace.WithMaxExportBatchSize(16), sdktrace.WithBatchTimeout(5*time.Second), sdktrace.WithExportTimeout(3*time.Second))
	if filtered {
		processor = requestProcessor{next: processor}
	}
	identity := resource.NewSchemaless(attribute.String("service.name", "boohtacord-api"), attribute.String("service.version", version))
	phase.provider = sdktrace.NewTracerProvider(sdktrace.WithResource(identity), sdktrace.WithSampler(sdktrace.AlwaysSample()), sdktrace.WithSpanProcessor(processor))
	phase.reader = sdkmetric.NewManualReader()
	phase.meter = sdkmetric.NewMeterProvider(sdkmetric.WithResource(identity), sdkmetric.WithReader(phase.reader))
	otel.SetMeterProvider(phase.meter)
	phase.recorder = httpmetrics.New()
	phase.store = presencememory.New(nil)
	service, err := presence.New(phase.authority, measurementPublication{}, phase.store, nil)
	if err != nil {
		t.Fatal(err)
	}
	mux := http.NewServeMux()
	presenceapi.RegisterRoutes(mux, measurementAuthenticator{}, service)
	phase.server = httptest.NewServer(phase.recorder.Middleware(tracehttp.Middleware(phase.provider.Tracer("boohtacord/qa-presence"), mux, mux), mux))
	return phase
}
func (p *measurementPhase) close() {
	p.server.Close()
	p.provider.Shutdown(context.Background())
	p.sink.Close()
	p.meter.Shutdown(context.Background())
	p.store.Close()
}

func measurementEndpoint(t *testing.T, key string) string {
	t.Helper()
	raw := os.Getenv(key)
	if raw == "" {
		t.Fatal("private QA endpoint required: " + key)
	}
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Scheme != "http" || parsed.User != nil {
		t.Fatal("invalid private QA endpoint")
	}
	ip := net.ParseIP(parsed.Hostname())
	if parsed.Hostname() != "localhost" && (ip == nil || !ip.IsLoopback()) {
		t.Fatal("measurement must target isolated loopback services")
	}
	return strings.TrimRight(raw, "/")
}

func assertMeasurementMetrics(t *testing.T, p *measurementPhase, data *metricdata.ResourceMetrics) {
	t.Helper()
	totals := map[int]int64{}
	durations := map[int]uint64{}
	for _, scope := range data.ScopeMetrics {
		for _, metric := range scope.Metrics {
			if metric.Name == "boohtacord.incident.http.requests" {
				if sum, ok := metric.Data.(metricdata.Sum[int64]); ok {
					for _, point := range sum.DataPoints {
						status, _ := point.Attributes.Value("status")
						code, _ := strconv.Atoi(status.AsString())
						totals[code] += point.Value
						for _, attr := range point.Attributes.ToSlice() {
							if strings.Contains(string(attr.Key), "id") || strings.Contains(attr.Value.AsString(), "11111111") {
								t.Fatal("private ID in aggregate labels")
							}
						}
					}
				}
			}
			if metric.Name == "boohtacord.incident.http.duration" {
				if histogram, ok := metric.Data.(metricdata.Histogram[float64]); ok {
					for _, point := range histogram.DataPoints {
						status, _ := point.Attributes.Value("status")
						code, _ := strconv.Atoi(status.AsString())
						durations[code] += point.Count
					}
				}
			}
		}
	}
	if totals[204] != 122 || totals[503] != 1 || totals[401] != 1 || durations[204] != 122 || durations[503] != 1 || durations[401] != 1 {
		t.Fatalf("%s aggregate count/duration mismatch", p.version)
	}
}

func assertMeasurementStored(t *testing.T, ctx context.Context, client *http.Client, tempo, version string, started time.Time, captured []*tracepb.Span, want int) int {
	t.Helper()
	deadline := time.Now().Add(30 * time.Second)
	stored := 0
	for time.Now().Before(deadline) {
		query := url.Values{"q": {`{ resource.service.version = "` + version + `" }`}, "start": {strconv.FormatInt(started.Add(-time.Second).Unix(), 10)}, "end": {strconv.FormatInt(time.Now().Add(time.Second).Unix(), 10)}, "limit": {"500"}, "spss": {"5"}}
		response, err := client.Get(tempo + "/api/search?" + query.Encode())
		if err == nil {
			var result struct {
				Traces []json.RawMessage `json:"traces"`
			}
			decode := json.NewDecoder(io.LimitReader(response.Body, 4<<20)).Decode(&result)
			response.Body.Close()
			if response.StatusCode == 200 && decode == nil {
				stored = len(result.Traces)
				if stored == want {
					break
				}
			}
		}
		select {
		case <-ctx.Done():
			t.Fatal("Tempo readback timed out")
		case <-time.After(500 * time.Millisecond):
		}
	}
	if stored != want {
		t.Fatalf("%s Collector accepted but Tempo stored count=%d want=%d", version, stored, want)
	}
	required := map[string]bool{"started": false, "stopped": false, "failure": false, "preauth": false}
	for _, span := range captured {
		status := int64(0)
		hasUser := false
		for _, a := range span.Attributes {
			if a.Key == "http.response.status_code" {
				status = a.Value.GetIntValue()
			}
			if a.Key == "user.id" {
				hasUser = true
			}
		}
		key := ""
		if status == 503 {
			key = "failure"
		}
		if status == 401 {
			key = "preauth"
			if hasUser {
				t.Fatal("prelogin failure misattributed")
			}
		}
		for _, event := range span.Events {
			if event.Name == "app.screen.viewer.started" {
				key = "started"
			}
			if event.Name == "app.screen.viewer.stopped" {
				key = "stopped"
			}
		}
		if key == "" {
			continue
		}
		response, err := client.Get(tempo + "/api/traces/" + hex.EncodeToString(span.TraceId))
		if err != nil {
			t.Fatal("stored diagnostic trace unavailable")
		}
		body, err := io.ReadAll(io.LimitReader(response.Body, 2<<20))
		response.Body.Close()
		if err != nil || response.StatusCode != 200 {
			t.Fatal("stored diagnostic trace readback failed")
		}
		if !bytes.Contains(body, []byte(span.Name)) {
			t.Fatal("stored trace lost span name")
		}
		if key == "preauth" && bytes.Contains(body, []byte("user.id")) {
			t.Fatal("stored preauth identity invented")
		}
		required[key] = true
	}
	for key, found := range required {
		if !found {
			t.Fatalf("%s missing stored %s diagnostic", version, key)
		}
	}
	return stored
}

func assertMeasurementPrometheus(t *testing.T, ctx context.Context, client *http.Client, metrics, version string) {
	t.Helper()
	deadline := time.Now().Add(15 * time.Second)
	for time.Now().Before(deadline) {
		response, err := client.Get(metrics + "/metrics")
		if err == nil {
			body, _ := io.ReadAll(io.LimitReader(response.Body, 4<<20))
			response.Body.Close()
			text := string(body)
			found := false
			for _, line := range strings.Split(text, "\n") {
				if strings.HasPrefix(line, "boohtacord_incident_http_requests_total{") && strings.Contains(line, `service_version="`+version+`"`) {
					found = true
					if strings.Contains(line, "user_id=") || strings.Contains(line, "session_id=") || strings.Contains(line, "flow_id=") || strings.Contains(line, "visit_id=") || strings.Contains(line, "media_id=") {
						t.Fatal("stored aggregate contains private ID")
					}
				}
			}
			if found {
				return
			}
		}
		select {
		case <-ctx.Done():
			t.Fatal(errors.New("stored aggregate check timed out"))
		case <-time.After(250 * time.Millisecond):
		}
	}
	t.Fatal("HTTP aggregates not found after actual Collector exporter")
}
