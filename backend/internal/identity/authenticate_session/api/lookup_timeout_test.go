package sessionapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
)

func TestRequireLookupDeadlineFailsUnavailableWithoutRosterOrPrincipal(t *testing.T) {
	middleware := Require(authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
		return authenticatesession.Principal{}, context.DeadlineExceeded
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/voice/participants", nil)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "test-cookie"})
	recorder := httptest.NewRecorder()
	middleware(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Error("lookup failure reached protected handler") })).ServeHTTP(recorder, request)
	if recorder.Code != 503 || recorder.Header().Get("Retry-After") != "1" || !strings.Contains(recorder.Body.String(), `"code":"VOICE_PRESENCE_UNAVAILABLE"`) {
		t.Errorf("lookup deadline did not produce structured503, status=%d", recorder.Code)
	}
	if strings.Contains(recorder.Body.String(), `"channels"`) {
		t.Error("lookup failure fabricated roster")
	}
}
func TestRequireSuccessPreservesLongLivedOriginalContext(t *testing.T) {
	ctx := context.WithValue(context.Background(), principalKey{}, "test-parent")
	middleware := Require(authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
		return authenticatesession.Principal{AccountID: "test-actor", Role: "MEMBER"}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/voice/rosters/events", nil).WithContext(ctx)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "test-cookie"})
	called := false
	middleware(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		called = true
		if r.Context().Err() != nil {
			t.Error("successful auth cancelled stream context")
		}
		if _, ok := r.Context().Deadline(); ok {
			t.Error("initial auth deadline leaked into long-lived SSE")
		}
		if _, ok := PrincipalFrom(r.Context()); !ok {
			t.Error("verified principal missing")
		}
	})).ServeHTTP(httptest.NewRecorder(), request)
	if !called {
		t.Error("protected stream not called")
	}
}

func TestLookupDeadlineResponseScopePreservesOtherAuthenticationFailures(t *testing.T) {
	for _, path := range []string{"/api/v1/voice/participants", "/api/v1/voice/rosters/events", "/protected"} {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		req.AddCookie(&http.Cookie{Name: session.CookieName, Value: "test-cookie"})
		auth := authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
			return authenticatesession.Principal{}, context.DeadlineExceeded
		})
		r := httptest.NewRecorder()
		Require(auth)(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Error("failed lookup reached handler") })).ServeHTTP(r, req)
		expected := http.StatusServiceUnavailable
		if path == "/protected" {
			expected = http.StatusInternalServerError
		}
		if r.Code != expected {
			t.Errorf("path=%s status=%d expected=%d", path, r.Code, expected)
		}
		optional := httptest.NewRecorder()
		Optional(auth)(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Error("failed optional lookup reached handler") })).ServeHTTP(optional, req)
		if optional.Code != http.StatusInternalServerError {
			t.Error("optional auth changed its generic failure response")
		}
	}
}
