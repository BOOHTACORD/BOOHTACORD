package centralexport

import (
	"context"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	"testing"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestDeliveryHealthReportsLostBatchesAndBoundedBuildWithoutPrivateConfig(t *testing.T) {
	i, _ := identity.New()
	i.Mode = "central"
	i.Credential = "private-credential"
	i.Endpoint = "https://private-endpoint.example"
	r := New(i, nil, nil)
	for n := 0; n < 33; n++ {
		r.Enqueue("traces", []byte{1})
	}
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	defer provider.Shutdown(context.Background())
	stop, err := r.RegisterMetrics(provider, "1.0.44")
	if err != nil {
		t.Fatal(err)
	}
	defer stop()
	var output metricdata.ResourceMetrics
	if err := reader.Collect(context.Background(), &output); err != nil {
		t.Fatal(err)
	}
	seen := map[string]bool{}
	for _, scope := range output.ScopeMetrics {
		for _, m := range scope.Metrics {
			seen[m.Name] = true
			switch v := m.Data.(type) {
			case metricdata.Gauge[int64]:
				for _, p := range v.DataPoints {
					if m.Name == "boohtacord.telemetry.queue.batches" && p.Value != 32 {
						t.Fatal("queue not bounded")
					}
					if m.Name == "boohtacord.telemetry.build.info" {
						value, _ := p.Attributes.Value("service_version")
						if value.AsString() != "1.0.44" {
							t.Fatal("missing build version")
						}
					}
				}
			case metricdata.Sum[int64]:
				if m.Name == "boohtacord.telemetry.dropped.batches" && v.DataPoints[0].Value != 1 {
					t.Fatal("drop not observable")
				}
			}
		}
	}
	for _, name := range []string{"boohtacord.telemetry.queue.batches", "boohtacord.telemetry.dropped.batches", "boohtacord.telemetry.build.info"} {
		if !seen[name] {
			t.Fatal("missing delivery health")
		}
	}
}
