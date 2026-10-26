package ingestclienttraces

import (
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	resourcepb "go.opentelemetry.io/proto/otlp/resource/v1"
	"testing"
)

func TestSanitizerSeparatesValidatedPlatformFromProducer(t *testing.T) {
	for platform := range platforms {
		input := flowBatch(flowSpan())
		input.ResourceSpans[0].Resource = &resourcepb.Resource{Attributes: []*commonpb.KeyValue{flowAttr("client.platform", "private-forged"), flowAttr("service.name", "spoof")}}
		output, result := sanitizeBatch(input, platform, "11111111111111111111111111111111", "verified")
		if result.Accepted != 1 {
			t.Fatal(result)
		}
		got := map[string]string{}
		for _, attr := range output.ResourceSpans[0].Resource.Attributes {
			got[attr.Key] = attr.Value.GetStringValue()
		}
		if got["client.platform"] != platform || got["service.name"] != "boohtacord-"+platform {
			t.Fatalf("wrong resource %v", got)
		}
	}
}
