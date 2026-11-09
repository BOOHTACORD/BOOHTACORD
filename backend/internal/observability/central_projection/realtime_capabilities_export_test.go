package centralprojection

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	sdkresource "go.opentelemetry.io/otel/sdk/resource"
	collect "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	"google.golang.org/protobuf/proto"
	metrics "voice-platform/backend/internal/observability/http_metrics"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestCapabilitySDKMetricsSurviveCentralProjection(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	captured := make(chan []byte, 1)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		data, _ := io.ReadAll(io.LimitReader(r.Body, 2<<20))
		captured <- data
		w.Header().Set("Content-Type", "application/x-protobuf")
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()
	exporter, err := otlpmetrichttp.New(ctx, otlpmetrichttp.WithEndpointURL(server.URL))
	if err != nil {
		t.Fatal(err)
	}
	resource := sdkresource.NewWithAttributes("", attribute.String("service.name", "boohtacord-api"))
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exporter)), sdkmetric.WithResource(resource))
	previous := otel.GetMeterProvider()
	otel.SetMeterProvider(provider)
	defer otel.SetMeterProvider(previous)
	defer provider.Shutdown(context.Background())
	recorder := metrics.New()
	recorder.RealtimeCapabilityOpened("both")
	recorder.RealtimeCapabilityOpened("neither")
	recorder.RealtimeCapabilityClosed("both")
	if err := provider.ForceFlush(ctx); err != nil {
		t.Fatal(err)
	}
	var raw []byte
	select {
	case raw = <-captured:
	case <-ctx.Done():
		t.Fatal("missing export")
	}
	installation, _ := identity.New()
	projected, err := Metrics(raw, installation)
	if err != nil {
		t.Fatal(err)
	}
	var batch collect.ExportMetricsServiceRequest
	if err := proto.Unmarshal(projected, &batch); err != nil {
		t.Fatal(err)
	}
	got := map[string]map[string]int64{}
	for _, resource := range batch.ResourceMetrics {
		for _, scope := range resource.ScopeMetrics {
			for _, item := range scope.Metrics {
				if item.Name != "voice_platform_realtime_capability_connections_active" && item.Name != "voice_platform_realtime_capability_connections_total" {
					continue
				}
				got[item.Name] = map[string]int64{}
				for _, point := range item.GetSum().GetDataPoints() {
					for _, a := range point.Attributes {
						if a.Key == "capability" {
							got[item.Name][a.Value.GetStringValue()] = point.GetAsInt()
						}
					}
				}
			}
		}
	}
	active := got["voice_platform_realtime_capability_connections_active"]
	total := got["voice_platform_realtime_capability_connections_total"]
	if len(active) != 4 || len(total) != 4 || active["both"] != 0 || active["neither"] != 1 || total["both"] != 1 || total["neither"] != 1 {
		t.Fatalf("projected metrics: %v", got)
	}
}
