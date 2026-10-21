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

func TestPrivateSFUDimensionsRemainDistinctWithoutPrivateNodeLabels(t *testing.T) {
	i, _ := identity.New()
	for _, direction := range []string{"incoming", "outgoing"} {
		labels := MetricLabels([]*common.KeyValue{String("node_type", "SERVER"), String("direction", direction), String("transmission", "initial"), String("source", "SCREEN_SHARE"), String("type", "VIDEO"), String("node_id", "PRIVATE_NODE"), String("country", "PRIVATE_LOCATION")}, i, "boohtacord-livekit", "")
		found := map[string]string{}
		for _, label := range labels {
			found[label.Key] = label.Value.GetStringValue()
		}
		if found["direction"] != direction || found["source"] != "SCREEN_SHARE" || found["type"] != "VIDEO" || found["transmission"] != "initial" {
			t.Fatal("distinct bounded SFU series collapsed")
		}
		if found["node_id"] != "" || found["country"] != "" {
			t.Fatal("private SFU label leaked")
		}
	}
}

func TestApprovedAPIAndMediaDimensionsDoNotCollapseDuringProjection(t *testing.T) {
	i, _ := identity.New()
	expected := map[string]string{"route": "GET /api/v1/channels", "stat": "participants", "stage": "decoded", "role": "actual_short_edge", "field": "fps", "outcome": "failure", "operation": "metric_export", "freshness": "fresh", "source": "client_report"}
	var in []*common.KeyValue
	for k, v := range expected {
		in = append(in, String(k, v))
	}
	found := map[string]string{}
	for _, v := range MetricLabels(in, i, "boohtacord-api", "") {
		found[v.Key] = v.Value.GetStringValue()
	}
	for key, value := range expected {
		if found[key] != value {
			t.Fatalf("bounded dimension dropped: %s", key)
		}
	}
}

func TestDiscardedPrivateDimensionsCannotProduceConflictingSeries(t *testing.T) {
	i, _ := identity.New()
	points := []*metric.NumberDataPoint{}
	for _, private := range []string{"PRIVATE_A", "PRIVATE_B"} {
		points = append(points, &metric.NumberDataPoint{Attributes: []*common.KeyValue{String("private_dimension", private)}, Value: &metric.NumberDataPoint_AsInt{AsInt: 1}})
	}
	batch := &collector.ExportMetricsServiceRequest{ResourceMetrics: []*metric.ResourceMetrics{{ScopeMetrics: []*metric.ScopeMetrics{{Metrics: []*metric.Metric{{Name: "boohtacord.users.registered", Data: &metric.Metric_Gauge{Gauge: &metric.Gauge{DataPoints: points}}}}}}}}}
	raw, _ := proto.Marshal(batch)
	if _, err := Metrics(raw, i); err == nil {
		t.Fatal("conflicting projected points accepted")
	}
}
