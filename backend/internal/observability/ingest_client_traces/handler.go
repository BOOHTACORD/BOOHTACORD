package ingestclienttraces

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
	centralexport "voice-platform/backend/internal/observability/central_export"
	flow "voice-platform/backend/internal/observability/flow_contract"
	incident "voice-platform/backend/internal/observability/observe_incidents"

	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	"google.golang.org/protobuf/proto"
)

const maxBodyBytes = flow.MaxBatchBytes

// NewHandler accepts a bounded OTLP batch from an authenticated client and strips all user-controlled metadata.
type Options struct {
	Central   *centralexport.Runtime
	CausalKey string
}

func NewHandler(endpoint, authorization string, client *http.Client, options ...Options) http.Handler {
	proofKey := authorization
	var central *centralexport.Runtime
	if len(options) > 0 {
		central = options[0].Central
		proofKey = options[0].CausalKey
	}
	if central != nil {
		client = central.Transport()
		if endpoint == "" {
			endpoint = "http://boohtacord-local-export.invalid/v1/traces"
		}
	}
	if client == nil {
		client = &http.Client{Timeout: 3 * time.Second}
	}
	destination, err := url.Parse(endpoint)
	configured := err == nil && destination != nil && (destination.Scheme == "https" || destination.Scheme == "http") && destination.Host != "" && destination.User == nil && authorization != ""
	if central != nil {
		configured = true
	}
	incident.Default.SetEnabled("relay_export", configured)
	return withRelayHealth(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if central != nil {
			if claim := request.Header.Get("X-Installation-ID"); claim != "" && claim != central.Identity().ID {
				writer.WriteHeader(http.StatusBadRequest)
				return
			}
		}
		if !configured {
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		if !strings.HasPrefix(request.Header.Get("Content-Type"), "application/x-protobuf") {
			writer.WriteHeader(http.StatusUnsupportedMediaType)
			return
		}
		body, err := io.ReadAll(http.MaxBytesReader(writer, request.Body, maxBodyBytes))
		if err != nil {
			writer.WriteHeader(http.StatusRequestEntityTooLarge)
			return
		}
		var input collectortrace.ExportTraceServiceRequest
		if proto.Unmarshal(body, &input) != nil {
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		sessionID, accountID := diagnosticIdentity(request)
		if claimed := request.Header.Get("X-Telemetry-Session"); claimed != "" && claimed != sessionID {
			observeBatch(request.Context(), batchResult{Fatal: true, Reason: "session_mismatch"})
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		clean, result := sanitizeBatch(&input, request.Header.Get("X-Client-Platform"), sessionID, accountID)
		if result.Fatal || result.Accepted == 0 {
			observeBatch(request.Context(), result)
			writer.WriteHeader(http.StatusBadRequest)
			return
		}
		verifiedLinks(&input, clean, proofKey, accountID)
		if central != nil {
			for _, resource := range clean.ResourceSpans {
				for _, attr := range central.Attributes() {
					if string(attr.Key) != "service.instance.id" {
						resource.Resource.Attributes = append(resource.Resource.Attributes, flowAttrValue(string(attr.Key), attr.Value.AsString()))
					}
				}
			}
		}
		encoded, err := proto.Marshal(clean)
		if err != nil {
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		bounded, cancel := context.WithTimeout(request.Context(), 3*time.Second)
		defer cancel()
		outbound, err := http.NewRequestWithContext(bounded, http.MethodPost, endpoint, bytes.NewReader(encoded))
		if err != nil {
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		outbound.Header.Set("Content-Type", "application/x-protobuf")
		outbound.Header.Set("Authorization", authorization)
		rejected, err := exportRelay(client, outbound, result.Accepted)
		if err != nil {
			writer.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		result.Accepted -= rejected
		// Keep producer validation and Collector rejection distinct even when
		// both occur in one batch. Response totals still include both kinds.
		if rejected > 0 {
			observeBatch(request.Context(), batchResult{Rejected: rejected, Reason: "collector_rejected"})
		}
		observeBatch(request.Context(), result)
		result.Rejected += rejected
		accepted(writer, result)
	}))
}
