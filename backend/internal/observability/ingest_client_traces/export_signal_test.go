package ingestclienttraces

import (
	"bytes"
	"context"
	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	"google.golang.org/protobuf/proto"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
)

func TestCollectorPartialResponseRejectsInvalidCounts(t *testing.T) {
	for _, count := range []int64{-1, 3} {
		t.Run(strconv.FormatInt(count, 10), func(t *testing.T) {
			encoded, _ := proto.Marshal(&collectortrace.ExportTraceServiceResponse{PartialSuccess: &collectortrace.ExportTracePartialSuccess{RejectedSpans: count}})
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write(encoded) }))
			defer server.Close()
			request, _ := http.NewRequestWithContext(context.Background(), "POST", server.URL, bytes.NewReader(nil))
			if _, err := exportRelay(server.Client(), request, 2); err == nil {
				t.Fatal("invalid Collector rejection count accepted")
			}
		})
	}
}
