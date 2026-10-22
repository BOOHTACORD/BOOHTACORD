//go:build tracing_runtime

package ingestclienttraces

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	"go.opentelemetry.io/otel/sdk/resource"
)

func TestRelaySourceFailureRemainsDistinctAfterActualCollector(t *testing.T) {
	collector, prom := privateQA(t, "TRACE_QA_COLLECTOR_URL"), privateQA(t, "TRACE_QA_COLLECTOR_METRICS_URL")
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	client := &http.Client{Timeout: 3 * time.Second, Transport: &http.Transport{Proxy: nil}}
	exporter, err := otlpmetrichttp.New(ctx, otlpmetrichttp.WithEndpointURL(collector+"/v1/metrics"), otlpmetrichttp.WithInsecure(), otlpmetrichttp.WithHTTPClient(client))
	if err != nil {
		t.Fatal(err)
	}
	defer exporter.Shutdown(ctx)
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader), sdkmetric.WithResource(resource.NewSchemaless(attribute.String("service.name", "boohtacord-api"), attribute.String("service.version", "issue513-health"))))
	defer provider.Shutdown(ctx)
	meter := provider.Meter("boohtacord/relay")
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
			observeBatch(r.Context(), batchResult{Accepted: 1})
			accepted(w, batchResult{Accepted: 1})
			return
		}
		observeBatch(r.Context(), batchResult{Rejected: 1, Reason: "session_mismatch"})
		w.WriteHeader(503)
	}))
	for _, platform := range []string{"web", "ios"} {
		r := httptest.NewRequest("POST", "/synthetic", nil)
		r.Header.Set("X-Client-Platform", platform)
		handler.ServeHTTP(httptest.NewRecorder(), r)
	}
	var data metricdata.ResourceMetrics
	if err := reader.Collect(ctx, &data); err != nil {
		t.Fatal(err)
	}
	if err := exporter.Export(ctx, &data); err != nil {
		t.Fatal(err)
	}
	for ctx.Err() == nil {
		response, err := client.Get(prom + "/metrics")
		if err == nil {
			body, _ := io.ReadAll(io.LimitReader(response.Body, 4<<20))
			response.Body.Close()
			found := map[string]bool{}
			for _, line := range strings.Split(string(body), "\n") {
				if !strings.Contains(line, `service_version="issue513-health"`) {
					continue
				}
				if strings.HasPrefix(line, "boohtacord_telemetry_relay_last_accept_seconds{") {
					if strings.Contains(line, `platform="ios"`) {
						t.Fatal("failed source received successful acceptance freshness")
					}
					if strings.Contains(line, `platform="web"`) {
						found["fresh"] = true
					}
				}
				if strings.HasPrefix(line, "boohtacord_telemetry_relay_requests_total{") && strings.Contains(line, `platform="ios"`) && strings.Contains(line, `http_response_status_code="503"`) {
					found["failure"] = true
				}
				if strings.HasPrefix(line, "boohtacord_telemetry_relay_records_total{") && strings.Contains(line, `platform="ios"`) && strings.Contains(line, `reason="session_mismatch"`) {
					found["rejection"] = true
				}
				for _, forbidden := range []string{"user_id=", "session_id=", "visit_id=", "flow_id=", "request_id="} {
					if strings.Contains(line, forbidden) {
						t.Fatal("private ID label after Collector")
					}
				}
			}
			if found["fresh"] && found["failure"] && found["rejection"] {
				t.Log("actual Collector preserves source-specific failure, rejection and last-accept; failure is not made healthy by Web acceptance")
				return
			}
		}
		time.Sleep(250 * time.Millisecond)
	}
	t.Fatal("actual Collector source-scoped health contract unavailable")
}
