package loginapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	admitlogin "voice-platform/backend/internal/identity/admit_login"
	"voice-platform/backend/internal/identity/login_user"
	"voice-platform/backend/internal/identity/session"
)

func TestHandlerSetsSecureOpaqueSessionCookie(t *testing.T) {
	var captured loginuser.Input
	expiresAt := time.Now().Add(session.AbsoluteLifetime)
	handler := NewHandler(loginerFunc(func(_ context.Context, input loginuser.Input) (loginuser.Result, error) {
		captured = input
		return loginuser.Result{Token: "opaque-session-token", ExpiresAt: expiresAt}, nil
	}))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(`{"login":"egor","password":"correct horse battery staple"}`))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNoContent || captured.Login != "egor" || captured.Password != "correct horse battery staple" || recorder.Body.Len() != 0 {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
	cookies := recorder.Result().Cookies()
	if len(cookies) != 1 || cookies[0].Name != "vp_session" || cookies[0].Value != "opaque-session-token" || !cookies[0].HttpOnly || !cookies[0].Secure || cookies[0].SameSite != http.SameSiteLaxMode || cookies[0].Path != "/" || cookies[0].MaxAge <= 0 || cookies[0].Expires.Unix() != expiresAt.Unix() {
		t.Fatalf("cookie = %#v", cookies)
	}
}

func TestHandlerDoesNotIssueCookieForInvalidCredentials(t *testing.T) {
	handler := NewHandler(loginerFunc(func(context.Context, loginuser.Input) (loginuser.Result, error) {
		return loginuser.Result{}, loginuser.ErrInvalidCredentials
	}))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(`{"login":"egor","password":"wrong password"}`))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized || len(recorder.Result().Cookies()) != 0 || !strings.Contains(recorder.Body.String(), `"UNAUTHENTICATED"`) {
		t.Fatalf("status = %d, cookies = %#v, body = %q", recorder.Code, recorder.Result().Cookies(), recorder.Body.String())
	}
}

func TestHandlerHidesBlockedAccountUntilPasswordIsVerified(t *testing.T) {
	for _, candidate := range []struct {
		name, password string
		failure        error
		status         int
		code           string
	}{
		{"invalid", "wrong", loginuser.ErrInvalidCredentials, http.StatusUnauthorized, "UNAUTHENTICATED"},
		{"blocked after verified password", "correct", loginuser.ErrBlocked, http.StatusForbidden, "ACCOUNT_BLOCKED"},
	} {
		t.Run(candidate.name, func(t *testing.T) {
			handler := NewHandler(loginerFunc(func(_ context.Context, input loginuser.Input) (loginuser.Result, error) {
				if input.Password != candidate.password {
					return loginuser.Result{}, loginuser.ErrInvalidCredentials
				}
				return loginuser.Result{}, candidate.failure
			}))
			request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(`{"login":"egor","password":"`+candidate.password+`"}`))
			recorder := httptest.NewRecorder()
			handler.ServeHTTP(recorder, request)
			if recorder.Code != candidate.status || !strings.Contains(recorder.Body.String(), `"`+candidate.code+`"`) || len(recorder.Result().Cookies()) != 0 {
				t.Fatalf("status = %d, body = %s, cookies = %#v", recorder.Code, recorder.Body.String(), recorder.Result().Cookies())
			}
		})
	}
}

func TestAccountBudgetPrecedesEveryVerifierIncludingCorrectPassword(t *testing.T) {
	limiter, err := admitlogin.New(admitlogin.Config{Limit: 1, Window: time.Minute, MaxAccounts: 16})
	if err != nil {
		t.Fatal(err)
	}
	calls := 0
	handler := NewHandlerWithAdmission(loginerFunc(func(_ context.Context, input loginuser.Input) (loginuser.Result, error) {
		calls++
		if input.Password == "correct" {
			return loginuser.Result{Token: "synthetic", ExpiresAt: time.Now().Add(session.AbsoluteLifetime)}, nil
		}
		return loginuser.Result{}, loginuser.ErrInvalidCredentials
	}), limiter)
	request := func(login, password, remote string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(`{"login":"`+login+`","password":"`+password+`"}`))
		req.RemoteAddr = remote
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, req)
		return response
	}
	if got := request("EGOR", "wrong", "192.0.2.1:1"); got.Code != http.StatusUnauthorized {
		t.Fatalf("first failure status = %d", got.Code)
	}
	if got := request("egor", "wrong", "192.0.2.2:1"); got.Code != http.StatusTooManyRequests || got.Header().Get("Retry-After") != "60" {
		t.Fatalf("second failure status = %d, retry = %q", got.Code, got.Header().Get("Retry-After"))
	}
	if got := request("egor", "correct", "192.0.2.2:1"); got.Code != http.StatusTooManyRequests || calls != 1 || len(got.Result().Cookies()) != 0 {
		t.Fatalf("exhausted budget: status=%d verifier calls=%d cookies=%d; want 429/1/0", got.Code, calls, len(got.Result().Cookies()))
	}
}

type loginerFunc func(context.Context, loginuser.Input) (loginuser.Result, error)

func (function loginerFunc) Login(context context.Context, input loginuser.Input) (loginuser.Result, error) {
	return function(context, input)
}
