package centralprojection

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	sdkresource "go.opentelemetry.io/otel/sdk/resource"
	collect "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	"google.golang.org/protobuf/proto"
	identity "voice-platform/backend/internal/observability/installation"
	rosterws "voice-platform/backend/internal/observability/roster_ws_metrics"
)

func TestRosterWSSDKExportSurvivesCentralProjection(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	captured := make(chan []byte, 1)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		data, _ := io.ReadAll(io.LimitReader(r.Body, 2<<20))
		select {
		case captured <- data:
		default:
		}
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
	m := rosterws.New(prometheus.NewRegistry())
	m.Open()
	m.Delivery(time.Millisecond, "success", true)
	m.Delivery(time.Millisecond, "unavailable", false)
	m.Refresh(true)
	if err := provider.ForceFlush(ctx); err != nil {
		t.Fatal(err)
	}
	var raw []byte
	select {
	case raw = <-captured:
	case <-ctx.Done():
		t.Fatal("OTLP export missing")
	}
	installation, _ := identity.New()
	projected, err := Metrics(raw, installation)
	if err != nil {
		t.Fatalf("projection failed: %v", err)
	}
	var output collect.ExportMetricsServiceRequest
	if err := proto.Unmarshal(projected, &output); err != nil {
		t.Fatal(err)
	}
	names := map[string]bool{}
	outcomes := map[string]bool{}
	for _, res := range output.ResourceMetrics {
		for _, scope := range res.ScopeMetrics {
			for _, item := range scope.Metrics {
				names[item.Name] = true
				if item.Name == "voice_platform_voice_roster_ws_delivery_total" && item.GetSum() != nil {
					for _, point := range item.GetSum().DataPoints {
						for _, a := range point.Attributes {
							if a.Key == "outcome" {
								outcomes[a.Value.GetStringValue()] = true
							}
						}
					}
				}
			}
		}
	}
	for _, name := range []string{"voice_platform_voice_roster_ws_subscribers", "voice_platform_voice_roster_ws_initial_total", "voice_platform_voice_roster_ws_delivery_total", "voice_platform_voice_roster_ws_delivery_seconds", "voice_platform_voice_roster_ws_refresh_total", "voice_platform_voice_roster_ws_last_success_timestamp_seconds", "voice_platform_voice_roster_ws_observation_enabled"} {
		if !names[name] {
			t.Errorf("missing projected instrument %s", name)
		}
	}
	if !outcomes["success"] || !outcomes["unavailable"] {
		t.Fatal("bounded outcomes did not survive projection")
	}
	m.Close()
}
