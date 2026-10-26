package ingestclienttraces

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	"google.golang.org/protobuf/proto"
	"net/http"
	"strconv"
)

var relayRecords, _ = otel.Meter("boohtacord/relay").Int64Counter("boohtacord.telemetry.relay.records")

func observeBatch(ctx context.Context, result batchResult) {
	if result.Accepted > 0 {
		relayRecords.Add(ctx, int64(result.Accepted), metric.WithAttributes(attribute.String("outcome", "accepted"), attribute.String("reason", "none"), sourcePlatform(ctx)))
	}
	if result.Rejected > 0 || result.Fatal {
		count := result.Rejected
		if count == 0 {
			count = 1
		}
		relayRecords.Add(ctx, int64(count), metric.WithAttributes(attribute.String("outcome", "rejected"), attribute.String("reason", result.Reason), sourcePlatform(ctx)))
	}
}
func accepted(writer http.ResponseWriter, result batchResult) {
	response := &collectortrace.ExportTraceServiceResponse{}
	if result.Rejected > 0 {
		response.PartialSuccess = &collectortrace.ExportTracePartialSuccess{RejectedSpans: int64(result.Rejected), ErrorMessage: "unsupported_records"}
	}
	body, _ := proto.Marshal(response)
	writer.Header().Set("Content-Type", "application/x-protobuf")
	writer.Header().Set("X-Telemetry-Accepted", strconv.Itoa(result.Accepted))
	writer.Header().Set("X-Telemetry-Rejected", strconv.Itoa(result.Rejected))
	writer.WriteHeader(http.StatusAccepted)
	_, _ = writer.Write(body)
}
