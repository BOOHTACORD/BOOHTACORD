package rosterwsmetrics

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/common/expfmt"
	"go.opentelemetry.io/otel"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
)

func TestWSRosterMetricsExportBoundedLifecycleAndRefresh(t *testing.T) {
	previous := otel.GetMeterProvider()
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	otel.SetMeterProvider(provider)
	defer otel.SetMeterProvider(previous)
	defer provider.Shutdown(context.Background())
	registry := prometheus.NewRegistry()
	m := New(registry)
	m.Open()
	m.Delivery(20*time.Millisecond, "success", true)
	m.Delivery(30*time.Millisecond, "private secret", false)
	m.Refresh(true)
	m.Refresh(false)
	families, err := registry.Gather()
	if err != nil {
		t.Fatal(err)
	}
	var out strings.Builder
	for _, family := range families {
		if _, err := expfmt.MetricFamilyToText(&out, family); err != nil {
			t.Fatal(err)
		}
	}
	text := out.String()
	for _, want := range []string{
		`voice_platform_voice_roster_ws_subscribers 1`,
		`voice_platform_voice_roster_ws_initial_total{outcome="success"} 1`,
		`voice_platform_voice_roster_ws_delivery_total{outcome="failure"} 1`,
		`voice_platform_voice_roster_ws_delivery_seconds_count 2`,
		`voice_platform_voice_roster_ws_refresh_total{outcome="success"} 1`,
		`voice_platform_voice_roster_ws_refresh_total{outcome="failure"} 1`,
		`voice_platform_voice_roster_ws_observation_enabled 1`,
	} {
		if !strings.Contains(text, want) {
			t.Errorf("missing bounded metric %s", want)
		}
	}
	if strings.Contains(text, "private") || strings.Contains(text, "secret") {
		t.Fatal("metric leaked unbounded value")
	}
	var data metricdata.ResourceMetrics
	if err := reader.Collect(context.Background(), &data); err != nil {
		t.Fatal(err)
	}
	seen := map[string]bool{}
	for _, scope := range data.ScopeMetrics {
		for _, metric := range scope.Metrics {
			seen[metric.Name] = true
			if values, ok := metric.Data.(metricdata.Sum[int64]); ok {
				for _, point := range values.DataPoints {
					for _, label := range point.Attributes.ToSlice() {
						if strings.Contains(label.Value.AsString(), "private") || strings.Contains(label.Value.AsString(), "secret") {
							t.Fatal("OTel leaked an unbounded label")
						}
					}
				}
			}
		}
	}
	for _, name := range []string{"voice_platform_voice_roster_ws_subscribers", "voice_platform_voice_roster_ws_initial_total", "voice_platform_voice_roster_ws_delivery_total", "voice_platform_voice_roster_ws_delivery_seconds", "voice_platform_voice_roster_ws_refresh_total", "voice_platform_voice_roster_ws_last_success_timestamp_seconds", "voice_platform_voice_roster_ws_observation_enabled"} {
		if !seen[name] {
			t.Errorf("OTel missing %s", name)
		}
	}
	m.Close()
}
