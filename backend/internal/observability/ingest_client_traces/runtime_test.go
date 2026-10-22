//go:build tracing_runtime

package ingestclienttraces

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"google.golang.org/protobuf/proto"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"
	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	causal "voice-platform/backend/internal/observability/causal_reference"
	correlatesession "voice-platform/backend/internal/observability/correlate_session"
)

func privateQA(t *testing.T, key string) string {
	t.Helper()
	raw := os.Getenv(key)
	if raw == "" {
		t.Skip("isolated Collector/Tempo URL not configured")
	}
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Scheme != "http" || parsed.User != nil {
		t.Fatal("expected private synthetic QA endpoint")
	}
	ip := net.ParseIP(parsed.Hostname())
	if parsed.Hostname() != "localhost" && (ip == nil || !ip.IsPrivate() && !ip.IsLoopback()) {
		t.Fatal("QA must not target public production")
	}
	return strings.TrimRight(raw, "/")
}
func TestRuntimeRelayStoresSanitizedFlowInTempo(t *testing.T) {
	collector, tempo := privateQA(t, "TRACE_QA_COLLECTOR_URL"), privateQA(t, "TRACE_QA_TEMPO_URL")
	client := &http.Client{Timeout: 2 * time.Second, Transport: &http.Transport{Proxy: nil}}
	principal := authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", SessionDigest: [32]byte{1}}
	binding := correlatesession.Attributes(principal.AccountID, principal.SessionDigest)[1].Value.AsString()
	first := flowSpan()
	first.TraceId = make([]byte, 16)
	_, _ = rand.Read(first.TraceId)
	first.SpanId = make([]byte, 8)
	_, _ = rand.Read(first.SpanId)
	for _, attr := range first.Attributes {
		if attr.Key == "session.id" {
			attr.Value = flowAttr("session.id", binding).Value
		}
	}
	cause := causal.Cause{TraceID: strings.Repeat("a", 32), SpanID: strings.Repeat("b", 16), FlowID: strings.Repeat("c", 32), Version: 1}
	tid, sid := cause.IDs()
	first.Links = []*tracepb.Span_Link{{TraceId: tid, SpanId: sid, Attributes: []*commonpb.KeyValue{flowAttr("app.causal.ref", causal.Sign("synthetic-QA-only", principal.AccountID, cause, time.Now()))}}}
	bad := proto.Clone(first).(*tracepb.Span)
	bad.Name = "unknown-semantic-record"
	bad.SpanId = bytes.Repeat([]byte{9}, 8)
	body, _ := proto.Marshal(flowBatch(first, bad))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/telemetry/traces", bytes.NewReader(body))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), principal))
	request.Header.Set("Content-Type", "application/x-protobuf")
	request.Header.Set("X-Client-Platform", "web")
	request.Header.Set("X-Telemetry-Session", binding)
	response := httptest.NewRecorder()
	NewHandler(collector+"/v1/traces", "synthetic-QA-only", client).ServeHTTP(response, request)
	if response.Code != 202 || response.Header().Get("X-Telemetry-Accepted") != "1" || response.Header().Get("X-Telemetry-Rejected") != "1" {
		t.Fatalf("relay status=%d accepted=%s rejected=%s", response.Code, response.Header().Get("X-Telemetry-Accepted"), response.Header().Get("X-Telemetry-Rejected"))
	}
	traceID := hex.EncodeToString(first.TraceId)
	if os.Getenv("TRACE_QA_EXPECT_TEMPO_OUTAGE") == "1" {
		probe, err := client.Get(tempo + "/ready")
		if err == nil {
			probe.Body.Close()
			if probe.StatusCode == 200 {
				t.Fatal("expected actual Tempo outage")
			}
		}
		t.Log("relay accepted while actual Tempo is unavailable; waiting for bounded recovery")
	}
	deadline := time.Now().Add(30 * time.Second)
	for time.Now().Before(deadline) {
		fetched, err := client.Get(tempo + "/api/traces/" + traceID)
		if err == nil {
			stored, _ := io.ReadAll(io.LimitReader(fetched.Body, 1<<20))
			_ = fetched.Body.Close()
			if fetched.StatusCode == 200 {
				for _, required := range []string{"screen.view", "first_frame", "timeout", binding, principal.AccountID, "server_confirmed", "app.cause.flow.id", "client.platform"} {
					if !bytes.Contains(stored, []byte(required)) {
						t.Fatalf("stored trace missing %s", required)
					}
				}
				for _, forbidden := range []string{"dm.body", "secret", "spoof", "app.causal.ref", "unknown-semantic-record"} {
					if bytes.Contains(stored, []byte(forbidden)) {
						t.Fatalf("stored trace leaked %s", forbidden)
					}
				}
				t.Log("stored sanitized synthetic trace spans=1 rejected=1; client platform preserved")
				return
			}
		}
		time.Sleep(500 * time.Millisecond)
	}
	t.Fatal("relay accepted but trace was not found in Tempo within bounded window")
}
