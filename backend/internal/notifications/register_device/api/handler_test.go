package deviceapi

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	d "voice-platform/backend/internal/notifications/register_device"
	rate "voice-platform/backend/internal/security/rate_limit"
)

const own = "11111111-1111-4111-8111-111111111111"

type registrarSpy struct {
	calls int
	input d.Input
}

func (s *registrarSpy) Register(_ context.Context, in d.Input) (d.Enrollment, error) {
	s.calls++
	s.input = in
	return d.Enrollment{}, nil
}
func call(h Handler, method, path, body string, authenticated bool) *httptest.ResponseRecorder {
	r := httptest.NewRequest(method, path, strings.NewReader(body))
	if authenticated {
		r = r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: own, SessionDigest: [32]byte{3}}))
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	return w
}
func TestActorAndSessionNeverComeFromRegistrationBody(t *testing.T) {
	spy := &registrarSpy{}
	h := Handler{Register: spy, Ready: true}
	for _, body := range []string{`{"account_id":"other"}`, `{"session_digest":"other"}`, `{"token":"raw-fcm-token"}`, `{"relay_url":"https://untrusted"}`, `{} {}`} {
		if w := call(h, "POST", "/api/v1/notification-devices", body, true); w.Code != 400 {
			t.Fatal(w.Code, w.Body.String())
		}
	}
	if spy.calls != 0 {
		t.Fatal("forged registration reached service")
	}
	w := call(h, "POST", "/api/v1/notification-devices", `{"instance_id":"22222222-2222-4222-8222-222222222222","expected_generation":0,"transport":"mobile_relay","namespace":"staging","permission":"granted","consent_version":1}`, true)
	if w.Code != 200 || spy.calls != 1 || spy.input.AccountID != own || spy.input.SessionDigest != [32]byte{3} {
		t.Fatal("untrusted actor/session used")
	}
}
func TestUnavailableIsHonestAndNeverRegisters(t *testing.T) {
	spy := &registrarSpy{}
	h := Handler{Register: spy, Ready: false, Capabilities: map[string]any{"version": 1, "registration_available": false}}
	if w := call(h, "GET", "/api/v1/notification-devices/capabilities", "", false); w.Code != 401 {
		t.Fatal(w.Code)
	}
	w := call(h, "GET", "/api/v1/notification-devices/capabilities", "", true)
	if w.Code != 200 || !strings.Contains(w.Body.String(), `"registration_available":false`) {
		t.Fatal(w.Code, w.Body.String())
	}
	if w = call(h, "POST", "/api/v1/notification-devices", `{}`, true); w.Code != 503 || spy.calls != 0 {
		t.Fatal("unconfigured provider pretended ready")
	}
}
func TestRegistrationBudgetIsBoundedBeforeWork(t *testing.T) {
	limiter, _ := rate.New(rate.Config{Limit: 1, Window: time.Minute, MaxSources: 1})
	h := Handler{Ready: false, Limiter: limiter, Capabilities: map[string]any{"version": 1}}
	if w := call(h, "GET", "/api/v1/notification-devices/capabilities", "", true); w.Code != 200 {
		t.Fatal(w.Code)
	}
	if w := call(h, "POST", "/api/v1/notification-devices", `{}`, true); w.Code != 429 || w.Header().Get("Retry-After") == "" {
		t.Fatal("budget bypass")
	}
}
