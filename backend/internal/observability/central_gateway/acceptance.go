package centralgateway

import (
	metrics "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	trace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	"google.golang.org/protobuf/proto"
)

func fullAcceptance(path string, body []byte) bool {
	if path == "/v1/traces" {
		var result trace.ExportTraceServiceResponse
		if proto.Unmarshal(body, &result) != nil {
			return false
		}
		p := result.PartialSuccess
		return p == nil || p.RejectedSpans == 0 && p.ErrorMessage == ""
	}
	var result metrics.ExportMetricsServiceResponse
	if proto.Unmarshal(body, &result) != nil {
		return false
	}
	p := result.PartialSuccess
	return p == nil || p.RejectedDataPoints == 0 && p.ErrorMessage == ""
}
