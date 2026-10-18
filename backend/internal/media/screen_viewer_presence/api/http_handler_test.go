package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	presence "voice-platform/backend/internal/media/screen_viewer_presence"
)

const viewerLease = "11111111-1111-4111-8111-111111111111"
const ownerLease = "22222222-2222-4222-8222-222222222222"

type authStub struct{}

func (authStub) Authenticate(_ context.Context, token string) (authenticatesession.Principal, error) {
	if token != "valid-session" {
		return authenticatesession.Principal{}, authenticatesession.ErrUnauthenticated
	}
	return authenticatesession.Principal{AccountID: "viewer-account", SessionDigest: [32]byte{1}}, nil
}

type operationsStub struct {
	viewers            []string
	watch, stop, clear int
	owner              string
	viewer             string
	track              string
}

func (stub *operationsStub) Watch(_ context.Context, _ presence.Principal, viewer, owner, track string) error {
	stub.watch++
	stub.viewer, stub.owner, stub.track = viewer, owner, track
	return nil
}
func (stub *operationsStub) StopWatching(_ context.Context, _ presence.Principal, viewer, owner, track string) error {
	stub.stop++
	stub.viewer, stub.owner, stub.track = viewer, owner, track
	return nil
}
func (stub *operationsStub) Viewers(_ context.Context, _ presence.Principal, owner string) ([]string, error) {
	stub.owner = owner
	return stub.viewers, nil
}
func (stub *operationsStub) ClearOwner(_ context.Context, _ presence.Principal, owner, track string) error {
	stub.clear++
	stub.owner, stub.track = owner, track
	return nil
}

func TestViewerPresenceMutationAndOwnerSnapshotArePrivateAndNoStore(t *testing.T) {
	operations := &operationsStub{viewers: []string{"33333333-3333-4333-8333-333333333333"}}
	mux := http.NewServeMux()
	RegisterRoutes(mux, authStub{}, operations)
	request := httptest.NewRequest(http.MethodPut, "/api/v1/voice/leases/"+viewerLease+"/screen-viewers/"+ownerLease, strings.NewReader(`{"track_sid":"TR_screen"}`))
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusNoContent || operations.watch != 1 || operations.viewer != viewerLease || operations.owner != ownerLease || operations.track != "TR_screen" {
		t.Fatalf("watch response=%d op=%+v", response.Code, operations)
	}
	assertPrivateHeaders(t, response)

	request = httptest.NewRequest(http.MethodGet, "/api/v1/voice/leases/"+ownerLease+"/screen-viewers", nil)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	response = httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	var body struct {
		ViewerAccountIDs []string `json:"viewer_account_ids"`
	}
	if response.Code != http.StatusOK || json.Unmarshal(response.Body.Bytes(), &body) != nil || len(body.ViewerAccountIDs) != 1 || body.ViewerAccountIDs[0] != operations.viewers[0] {
		t.Fatalf("snapshot=%d %q", response.Code, response.Body.String())
	}
	assertPrivateHeaders(t, response)

	request = httptest.NewRequest(http.MethodDelete, "/api/v1/voice/leases/"+viewerLease+"/screen-viewers/"+ownerLease+"?track_sid=TR_screen", nil)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	response = httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusNoContent || operations.stop != 1 || operations.track != "TR_screen" {
		t.Fatalf("stop response=%d op=%+v", response.Code, operations)
	}
}

func TestOnlyOwnerCanClearAudienceAndInvalidPayloadIsRejected(t *testing.T) {
	operations := &operationsStub{}
	mux := http.NewServeMux()
	RegisterRoutes(mux, authStub{}, operations)
	request := httptest.NewRequest(http.MethodDelete, "/api/v1/voice/leases/"+ownerLease+"/screen-viewers?track_sid=TR_screen", nil)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusNoContent || operations.clear != 1 || operations.owner != ownerLease || operations.track != "TR_screen" {
		t.Fatalf("clear response=%d op=%+v", response.Code, operations)
	}

	request = httptest.NewRequest(http.MethodPut, "/api/v1/voice/leases/"+viewerLease+"/screen-viewers/"+ownerLease, strings.NewReader(`{"track_sid":"TR_bad","extra":"value"}`))
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	response = httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest || operations.watch != 0 {
		t.Fatalf("invalid body response=%d op=%+v", response.Code, operations)
	}
}

func TestViewerPresenceRequiresAuthenticatedSession(t *testing.T) {
	mux := http.NewServeMux()
	RegisterRoutes(mux, authStub{}, &operationsStub{})
	request := httptest.NewRequest(http.MethodGet, "/api/v1/voice/leases/"+ownerLease+"/screen-viewers", nil)
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("unauthenticated status=%d", response.Code)
	}
}

func assertPrivateHeaders(t *testing.T, response *httptest.ResponseRecorder) {
	t.Helper()
	if response.Header().Get("Cache-Control") != "private, no-store, max-age=0" || response.Header().Get("X-Content-Type-Options") != "nosniff" || response.Header().Get("Vary") != "Cookie" {
		t.Fatalf("private headers missing: %#v", response.Header())
	}
}
