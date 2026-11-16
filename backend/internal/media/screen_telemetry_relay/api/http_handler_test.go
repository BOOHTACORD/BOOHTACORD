package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	relay "voice-platform/backend/internal/media/screen_telemetry_relay"
)

const ownerLeaseID = "22222222-2222-4222-8222-222222222222"
const ownerAccountID = "11111111-1111-4111-8111-111111111111"

const validEnvelopeJSON = `{"schema_version":1,"media_session_id":"session-a","publication_generation":4,"platform":"web","client_kind":"web","capability_version":1,"sequence":1,"capture":{"width":{"value":1920,"availability":"measured","provenance":"sender_measured"},"height":{"value":1080,"availability":"measured","provenance":"sender_measured"},"fps":{"value":30,"availability":"measured","provenance":"sender_measured"}},"encode":{"fps":{"value":29,"availability":"measured","provenance":"sender_measured"},"bitrate_bps":{"value":1500000,"availability":"measured","provenance":"sender_measured"}},"transport":{"packet_loss_percent":{"value":0.4,"availability":"measured","provenance":"sender_measured"},"rtt_ms":{"value":50,"availability":"measured","provenance":"sender_measured"},"quality_limitation_reason":{"value":"bandwidth","availability":"measured","provenance":"sender_measured"}}}`

type authStub struct{}

func (authStub) Authenticate(_ context.Context, token string) (authenticatesession.Principal, error) {
	if token != "valid-session" {
		return authenticatesession.Principal{}, authenticatesession.ErrUnauthenticated
	}
	return authenticatesession.Principal{AccountID: ownerAccountID, SessionDigest: [32]byte{1}}, nil
}

type operationsStub struct {
	principal relay.Principal
	leaseID   string
	envelope  relay.ScreenTelemetryEnvelopeV1
	err       error
	calls     int
}

func (stub *operationsStub) Publish(_ context.Context, principal relay.Principal, leaseID string, envelope relay.ScreenTelemetryEnvelopeV1) error {
	stub.calls++
	stub.principal, stub.leaseID, stub.envelope = principal, leaseID, envelope
	return stub.err
}

func TestPublishScreenTelemetryIsAuthenticatedPrivateAndStrictlyDecoded(t *testing.T) {
	operations := &operationsStub{}
	mux := http.NewServeMux()
	RegisterRoutes(mux, authStub{}, operations)
	request := httptest.NewRequest(http.MethodPost, "/api/v1/voice/leases/"+ownerLeaseID+"/screen-telemetry", strings.NewReader(validEnvelopeJSON))
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusNoContent || operations.calls != 1 || operations.leaseID != ownerLeaseID || operations.envelope.Sequence != 1 {
		t.Fatalf("publish response=%d operations=%+v body=%q", response.Code, operations, response.Body.String())
	}
	if response.Header().Get("Cache-Control") != "private, no-store, max-age=0" || response.Header().Get("X-Content-Type-Options") != "nosniff" || response.Header().Get("Vary") != "Cookie" {
		t.Fatalf("private headers missing: %#v", response.Header())
	}

	request = httptest.NewRequest(http.MethodPost, "/api/v1/voice/leases/"+ownerLeaseID+"/screen-telemetry", strings.NewReader(strings.TrimSuffix(validEnvelopeJSON, "}")+`,"window_title":"private"}`))
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	response = httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest || operations.calls != 1 {
		t.Fatalf("unknown privacy field was not rejected: status=%d calls=%d", response.Code, operations.calls)
	}

	request = httptest.NewRequest(http.MethodPost, "/api/v1/voice/leases/"+ownerLeaseID+"/screen-telemetry", strings.NewReader(validEnvelopeJSON))
	response = httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("unauthenticated status=%d", response.Code)
	}
}

func TestPublishScreenTelemetryRejectsOversizedPayloadBeforeOperation(t *testing.T) {
	operations := &operationsStub{}
	mux := http.NewServeMux()
	RegisterRoutes(mux, authStub{}, operations)
	request := httptest.NewRequest(http.MethodPost, "/api/v1/voice/leases/"+ownerLeaseID+"/screen-telemetry", strings.NewReader(validEnvelopeJSON+strings.Repeat(" ", 2048)))
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest || operations.calls != 0 {
		t.Fatalf("oversized payload status=%d calls=%d", response.Code, operations.calls)
	}
}
