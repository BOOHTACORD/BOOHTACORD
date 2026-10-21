package centralgateway

import (
	trace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	"google.golang.org/protobuf/proto"
	"testing"
)

func TestEmptyPartialSuccessIsFullAcceptanceButRejectedSpansAreNot(t *testing.T) {
	empty, _ := proto.Marshal(&trace.ExportTraceServiceResponse{PartialSuccess: &trace.ExportTracePartialSuccess{}})
	rejected, _ := proto.Marshal(&trace.ExportTraceServiceResponse{PartialSuccess: &trace.ExportTracePartialSuccess{RejectedSpans: 1}})
	if !fullAcceptance("/v1/traces", nil) || !fullAcceptance("/v1/traces", empty) || fullAcceptance("/v1/traces", rejected) || fullAcceptance("/v1/traces", []byte("malformed")) {
		t.Fatal("upstream acceptance incorrectly classified")
	}
}
