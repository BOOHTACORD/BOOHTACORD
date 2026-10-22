package ingestclienttraces

import (
	"errors"
	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	"google.golang.org/protobuf/proto"
	"io"
	"net/http"
	"time"
	incident "voice-platform/backend/internal/observability/observe_incidents"
)

func exportRelay(client *http.Client, outbound *http.Request, accepted int) (rejected int, result error) {
	started := time.Now()
	partialFailure := false
	defer func() {
		observed := result
		if partialFailure {
			observed = errors.New("collector partial rejection")
		}
		incident.Observe("relay_export", started, observed)
	}()
	response, err := client.Do(outbound)
	if err != nil {
		return 0, err
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 4097))
	if response.StatusCode != 200 || err != nil || len(body) > 4096 {
		return 0, errors.New("collector response failed")
	}
	if len(body) == 0 {
		return 0, nil
	}
	var reply collectortrace.ExportTraceServiceResponse
	if proto.Unmarshal(body, &reply) != nil {
		return 0, errors.New("collector response invalid")
	}
	if partial := reply.PartialSuccess; partial != nil {
		if partial.RejectedSpans < 0 {
			return 0, errors.New("collector count invalid")
		}
		if partial.RejectedSpans == 0 {
			return 0, nil
		}
		if partial.RejectedSpans > int64(accepted) {
			return 0, errors.New("collector count invalid")
		}
		partialFailure = true
		return int(partial.RejectedSpans), nil
	}
	return 0, nil
}
