package centralprojection

import (
	"bytes"
	collector "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	common "go.opentelemetry.io/proto/otlp/common/v1"
	metric "go.opentelemetry.io/proto/otlp/metrics/v1"
	"google.golang.org/protobuf/proto"
	"testing"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestMetricsDropsUnboundedLabelsAndUnknownNames(t *testing.T) {
	i, _ := identity.New()
	in := &collector.ExportMetricsServiceRequest{ResourceMetrics: []*metric.ResourceMetrics{{ScopeMetrics: []*metric.ScopeMetrics{{Metrics: []*metric.Metric{
		{Name: "boohtacord.http.server.requests", Data: &metric.Metric_Gauge{Gauge: &metric.Gauge{DataPoints: []*metric.NumberDataPoint{{Attributes: []*common.KeyValue{String("user.id", "PRIVATE"), String("platform", "macos"), String("codec", "PRIVATE")}, Value: &metric.NumberDataPoint_AsInt{AsInt: 1}}}}}},
		{Name: "arbitrary_PRIVATE", Data: &metric.Metric_Gauge{Gauge: &metric.Gauge{}}},
	}}}}}}
	raw, _ := proto.Marshal(in)
	out, err := Metrics(raw, i)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(out, []byte("PRIVATE")) {
		t.Fatal("unbounded metric leaked")
	}
	var clean collector.ExportMetricsServiceRequest
	proto.Unmarshal(out, &clean)
	if len(clean.ResourceMetrics[0].ScopeMetrics[0].Metrics) != 1 {
		t.Fatal("unknown metric accepted")
	}
	if !bytes.Contains(out, []byte(i.ID)) {
		t.Fatal("installation scope missing")
	}
}

func TestVersionLabelsAreBoundedAndCannotCarryFreeFormValues(t *testing.T) {
	i, _ := identity.New()
	for _, version := range []string{"1.0.44", "v1.0.44+79", "unknown", "private-account-name", "1.2.3+private-token"} {
		labels := MetricLabels([]*common.KeyValue{String("service_version", version)}, i, "boohtacord-api", "")
		found := false
		for _, entry := range labels {
			if entry.Key == "service_version" {
				found = true
			}
		}
		expected := version == "1.0.44" || version == "v1.0.44+79" || version == "unknown"
		if found != expected {
			t.Fatal("version label escaped bounded build contract")
		}
	}
}
