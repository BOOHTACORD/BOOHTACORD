package desktopupdate

import (
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	"testing"
)

func TestClosedVocabularyDropsUnboundedValues(t *testing.T) {
	input := []*commonpb.KeyValue{
		{Key: "phase", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "download"}}},
		{Key: "reason", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "/Users/private/file"}}},
		{Key: "draft", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "private text"}}},
	}
	out := Clean(input, "macos")
	if len(out) != 2 {
		t.Fatalf("unexpected attribute count %d", len(out))
	}
	for _, a := range out {
		if a.Key != "platform" && a.Key != "phase" {
			t.Fatal("unbounded attribute retained")
		}
	}
}
