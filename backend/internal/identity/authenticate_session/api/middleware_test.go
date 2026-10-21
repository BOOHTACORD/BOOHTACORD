package sessionapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
)

func TestRequireAddsVerifiedPrincipalToContext(t *testing.T) {
	expiresAt := time.Now().Add(session.AbsoluteLifetime)
	want := authenticatesession.Principal{AccountID: "account-1", Role: "MEMBER", ExpiresAt: expiresAt}
	middleware := Require(authenticatorFunc(func(_ context.Context, token string) (authenticatesession.Principal, error) {
		if token != "opaque-token" {
			t.Fatalf("token = %q", token)
		}
		return want, nil
	}))
	next := http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := PrincipalFrom(request.Context())
		if !ok || principal != want {
			t.Fatalf("principal = %#v, ok = %t", principal, ok)
		}
		writer.WriteHeader(http.StatusNoContent)
	})
	request := httptest.NewRequest(http.MethodGet, "/protected", nil)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "opaque-token"})
	recorder := httptest.NewRecorder()

	middleware(next).ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNoContent {
		t.Fatalf("status = %d", recorder.Code)
	}
	cookies := recorder.Result().Cookies()
	if len(cookies) != 1 || cookies[0].Name != session.CookieName || cookies[0].Value != "opaque-token" || cookies[0].MaxAge <= 0 || cookies[0].Expires.Unix() != expiresAt.Unix() {
		t.Fatalf("renewed session cookie = %#v", cookies)
	}
}

func TestOptionalRenewsCookieForExistingBrowserSession(t *testing.T) {
	expiresAt := time.Now().Add(session.AbsoluteLifetime)
	want := authenticatesession.Principal{AccountID: "account-1", Role: "MEMBER", ExpiresAt: expiresAt}
	middleware := Optional(authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
		return want, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/auth/session", nil)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "opaque-token"})
	recorder := httptest.NewRecorder()
	middleware(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {})).ServeHTTP(recorder, request)

	cookies := recorder.Result().Cookies()
	if len(cookies) != 1 || cookies[0].Name != session.CookieName || cookies[0].Value != "opaque-token" || cookies[0].MaxAge <= 0 || cookies[0].Expires.Unix() != expiresAt.Unix() {
		t.Fatalf("renewed existing session cookie = %#v", cookies)
	}
}

func TestRequireRejectsMissingOrRevokedSession(t *testing.T) {
	middleware := Require(authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
		return authenticatesession.Principal{}, authenticatesession.ErrUnauthenticated
	}))
	next := http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Fatal("next must not run") })

	for _, request := range []*http.Request{
		httptest.NewRequest(http.MethodGet, "/protected", nil),
		func() *http.Request {
			request := httptest.NewRequest(http.MethodGet, "/protected", nil)
			request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "revoked-token"})
			return request
		}(),
	} {
		recorder := httptest.NewRecorder()
		middleware(next).ServeHTTP(recorder, request)
		if recorder.Code != http.StatusUnauthorized {
			t.Fatalf("status = %d", recorder.Code)
		}
	}
}

func TestOptionalAllowsMissingOrRevokedSessionAsGuest(t *testing.T) {
	middleware := Optional(authenticatorFunc(func(_ context.Context, token string) (authenticatesession.Principal, error) {
		if token != "revoked-token" {
			t.Fatalf("token = %q", token)
		}
		return authenticatesession.Principal{}, authenticatesession.ErrUnauthenticated
	}))
	next := http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if _, ok := PrincipalFrom(request.Context()); ok {
			t.Fatal("guest request unexpectedly has a principal")
		}
		writer.WriteHeader(http.StatusNoContent)
	})

	for _, request := range []*http.Request{
		httptest.NewRequest(http.MethodGet, "/api/v1/auth/session", nil),
		func() *http.Request {
			request := httptest.NewRequest(http.MethodGet, "/api/v1/auth/session", nil)
			request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "revoked-token"})
			return request
		}(),
	} {
		recorder := httptest.NewRecorder()
		middleware(next).ServeHTTP(recorder, request)
		if recorder.Code != http.StatusNoContent {
			t.Fatalf("status = %d", recorder.Code)
		}
	}
}

func TestOptionalRejectsAuthenticatorFailure(t *testing.T) {
	middleware := Optional(authenticatorFunc(func(context.Context, string) (authenticatesession.Principal, error) {
		return authenticatesession.Principal{}, errors.New("database unavailable")
	}))
	next := http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Fatal("next must not run") })
	request := httptest.NewRequest(http.MethodGet, "/api/v1/auth/session", nil)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "opaque-token"})
	recorder := httptest.NewRecorder()

	middleware(next).ServeHTTP(recorder, request)

	if recorder.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d", recorder.Code)
	}
}

type authenticatorFunc func(context.Context, string) (authenticatesession.Principal, error)

func (function authenticatorFunc) Authenticate(context context.Context, token string) (authenticatesession.Principal, error) {
	return function(context, token)
}
