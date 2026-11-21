package main

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
func TestLate401UsesActualProtectedEndpointWithoutCookie(t *testing.T) {
	s := newState("nonce")
	s.arm("session-late401")
	sentinel := errors.New("owned network stop")
	transport := faultTransport{state: s, base: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		if r.URL.Path != "/api/v1/channels" || r.Header.Get("Cookie") != "" {
			t.Error("401 did not come from actual protected admission")
		}
		return nil, sentinel
	})}
	r := httptest.NewRequest("GET", "http://owned/api/v1/auth/session", nil)
	r.Header.Set("Cookie", "synthetic-owned-cookie")
	_, err := transport.RoundTrip(r)
	if !errors.Is(err, sentinel) {
		t.Fatal("transport error changed")
	}
}
