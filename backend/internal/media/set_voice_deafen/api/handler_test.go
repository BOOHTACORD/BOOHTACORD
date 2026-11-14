package setvoicedeafenapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	setvoicedeafen "voice-platform/backend/internal/media/set_voice_deafen"
)

const testOrigin = "https://voice.example.test"

type operationsStub struct {
	lease     string
	principal setvoicedeafen.Principal
	deafened  bool
	calls     int
}

func (stub *operationsStub) Apply(_ context.Context, principal setvoicedeafen.Principal, lease string, deafened bool) error {
	stub.principal, stub.lease, stub.deafened = principal, lease, deafened
	stub.calls++
	return nil
}

func TestUpdateRequiresExactOriginAndStrictBooleanBody(t *testing.T) {
	for _, item := range []struct {
		origin, body string
		want         int
	}{{"", `{"deafened":true}`, http.StatusForbidden}, {"https://evil.example", `{"deafened":true}`, http.StatusForbidden}, {testOrigin, `{"deafened":true,"room":"other"}`, http.StatusBadRequest}, {testOrigin, `{"deafened":"true"}`, http.StatusBadRequest}, {testOrigin, `{"deafened":true} {}`, http.StatusBadRequest}, {testOrigin, `{"deafened":true}`, http.StatusNoContent}} {
		stub := &operationsStub{}
		handler := Handler{operations: stub, expectedOrigin: testOrigin, limiter: newSessionLimiter(20, time.Minute, 100)}
		request := httptest.NewRequest(http.MethodPut, "/api/v1/voice/leases/11111111-1111-4111-8111-111111111111/deafen/v1", strings.NewReader(item.body))
		request.Header.Set("Origin", item.origin)
		request.Header.Set("Content-Type", "application/json")
		request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "22222222-2222-4222-8222-222222222222"}))
		request.SetPathValue("leaseID", "11111111-1111-4111-8111-111111111111")
		recorder := httptest.NewRecorder()
		handler.update(recorder, request)
		if recorder.Code != item.want {
			t.Fatalf("origin=%q body=%s status=%d want=%d", item.origin, item.body, recorder.Code, item.want)
		}
		if item.want == http.StatusNoContent && (stub.calls != 1 || stub.lease != "11111111-1111-4111-8111-111111111111" || !stub.deafened) {
			t.Fatalf("operation=%+v", stub)
		}
	}
}

func TestSessionLimiterBoundsAndExpiresEntries(t *testing.T) {
	limiter := newSessionLimiter(1, time.Minute, 1)
	now := time.Now()
	var first, second [32]byte
	first[0] = 1
	second[0] = 2
	if !limiter.Allow(first, now) || limiter.Allow(first, now.Add(time.Second)) || limiter.Allow(second, now.Add(2*time.Second)) || !limiter.Allow(second, now.Add(time.Minute)) {
		t.Fatal("limiter did not enforce bounded session window")
	}
}
