package ratelimit

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestMiddlewareDoesNotTrustMalformedForwardedSource(t *testing.T) {
	request := &http.Request{RemoteAddr: "192.0.2.4:1234", Header: http.Header{"X-Forwarded-For": []string{"not-an-ip"}}}
	if source := sourceKey(request, nil); source != "192.0.2.4" {
		t.Fatalf("source = %q", source)
	}
}

func TestSourceKeyIgnoresForwardingFromUntrustedPeer(t *testing.T) {
	request := &http.Request{RemoteAddr: "192.0.2.4:1234", Header: http.Header{"X-Forwarded-For": []string{"203.0.113.9"}}}
	if source := sourceKey(request, nil); source != "192.0.2.4" {
		t.Fatalf("source = %q, want direct peer", source)
	}
}

func TestLimiterExposesSameTrustedSourceAsHandshakeRateLimit(t *testing.T) {
	limiter, err := New(Config{Limit: 1, Window: time.Minute, MaxSources: 8, TrustedProxyCIDRs: []string{"10.0.0.0/8"}})
	if err != nil {
		t.Fatal(err)
	}
	request := &http.Request{RemoteAddr: "10.0.0.5:443", Header: http.Header{"X-Forwarded-For": []string{"203.0.113.9, 10.0.0.4"}}}
	if source := limiter.SourceKey(request); source != "203.0.113.9" {
		t.Fatalf("trusted source = %q", source)
	}
	request.RemoteAddr = "192.0.2.4:1234"
	if source := limiter.SourceKey(request); source != "192.0.2.4" {
		t.Fatalf("untrusted peer source = %q", source)
	}
}

func TestSourceKeyWalksTrustedProxyChainFromNearestPeer(t *testing.T) {
	trusted, err := parseTrustedProxies([]string{"10.0.0.0/8"})
	if err != nil {
		t.Fatal(err)
	}
	request := &http.Request{RemoteAddr: "10.0.0.5:443", Header: http.Header{"X-Forwarded-For": []string{"203.0.113.9, 10.0.0.4"}}}
	if source := sourceKey(request, trusted); source != "203.0.113.9" {
		t.Fatalf("source = %q, want client at trust boundary", source)
	}
}

func TestLimiterMiddlewareUsesTrustedClientAndIgnoresUntrustedForwarding(t *testing.T) {
	limiter, err := New(Config{Limit: 1, Window: time.Minute, MaxSources: 8, TrustedProxyCIDRs: []string{"10.0.0.0/8"}})
	if err != nil {
		t.Fatal(err)
	}
	next := http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) { writer.WriteHeader(http.StatusNoContent) })
	call := func(remote, forwarded string) int {
		request := httptest.NewRequest(http.MethodGet, "/", nil)
		request.RemoteAddr = remote
		request.Header.Set("X-Forwarded-For", forwarded)
		recorder := httptest.NewRecorder()
		limiter.Middleware(next).ServeHTTP(recorder, request)
		return recorder.Code
	}
	if status := call("192.0.2.2:443", "203.0.113.1"); status != http.StatusNoContent {
		t.Fatalf("untrusted forwarded status = %d", status)
	}
	if status := call("192.0.2.2:443", "203.0.113.2"); status != http.StatusTooManyRequests {
		t.Fatalf("untrusted spoof status = %d", status)
	}
	if status := call("10.0.0.8:443", "203.0.113.1"); status != http.StatusNoContent {
		t.Fatalf("first trusted client status = %d", status)
	}
	if status := call("10.0.0.8:443", "203.0.113.1"); status != http.StatusTooManyRequests {
		t.Fatalf("same trusted client status = %d", status)
	}
	if status := call("10.0.0.8:443", "203.0.113.2"); status != http.StatusNoContent {
		t.Fatalf("second trusted client status = %d", status)
	}
}
