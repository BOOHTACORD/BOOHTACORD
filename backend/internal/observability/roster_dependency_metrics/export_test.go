package rosterdependencymetrics

import (
	"context"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	"strings"
	"testing"
	"time"
)

func TestLifecycleAndRPCMetricsExportThroughOTelWithBoundedLabels(t *testing.T) {
	previous := otel.GetMeterProvider()
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	otel.SetMeterProvider(provider)
	defer otel.SetMeterProvider(previous)
	defer provider.Shutdown(context.Background())
	m := New(prometheus.NewRegistry())
	m.Call("private room", "token secret", time.Millisecond)
	m.Snapshot(time.Millisecond, 5, false)
	m.Failure("presence_room_list")
	var data metricdata.ResourceMetrics
	if err := reader.Collect(context.Background(), &data); err != nil {
		t.Fatal(err)
	}
	seen := map[string]bool{}
	for _, scope := range data.ScopeMetrics {
		for _, metric := range scope.Metrics {
			seen[metric.Name] = true
			if strings.Contains(strings.ToLower(metric.Name), "secret") {
				t.Fatal("unbounded instrument")
			}
			if values, ok := metric.Data.(metricdata.Sum[int64]); ok {
				for _, point := range values.DataPoints {
					for _, label := range point.Attributes.ToSlice() {
						if strings.Contains(label.Value.AsString(), "private") || strings.Contains(label.Value.AsString(), "secret") {
							t.Fatalf("unbounded label=%v", label)
						}
					}
				}
			}
		}
	}
	for _, name := range []string{"voice_platform_sfu_room_service_calls_total", "voice_platform_voice_roster_failures_total"} {
		if !seen[name] {
			t.Fatalf("missing OTel instrument %s", name)
		}
	}
	for _, name := range []string{"voice_platform_voice_roster_streams_active", "voice_platform_voice_roster_initial_total", "voice_platform_voice_roster_stream_ends_total"} {
		if seen[name] {
			t.Fatalf("retired SSE instrument still exported: %s", name)
		}
	}
}
