package webpush

import (
	"context"
	"crypto/x509"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"sync/atomic"
	"testing"
)

type rebindingResolver struct{ calls atomic.Int32 }

func (r *rebindingResolver) LookupNetIP(context.Context, string, string) ([]netip.Addr, error) {
	if r.calls.Add(1) == 1 {
		return []netip.Addr{netip.MustParseAddr("8.8.8.8")}, nil
	}
	return []netip.Addr{netip.MustParseAddr("127.0.0.1")}, nil
}
func TestDialIsPinnedAndRedirectsAreNotFollowed(t *testing.T) {
	var requests atomic.Int32
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		w.Header().Set("Location", "https://127.0.0.1/private")
		w.WriteHeader(302)
	}))
	defer server.Close()
	cert := server.Certificate()
	host := cert.DNSNames[0]
	resolver := &rebindingResolver{}
	gate, err := NewGate([]string{host}, resolver)
	if err != nil {
		t.Fatal(err)
	}
	client := NewHTTPClient(gate)
	transport := client.Transport.(*safeTransport)
	roots := x509.NewCertPool()
	roots.AddCert(cert)
	transport.roots = roots
	var dials atomic.Int32
	transport.dial = func(ctx context.Context, network, address string) (net.Conn, error) {
		dials.Add(1)
		if address != "8.8.8.8:443" {
			t.Errorf("unvalidated dial target %q", address)
		}
		return (&net.Dialer{}).DialContext(ctx, network, server.Listener.Addr().String())
	}
	response, err := client.Get("https://" + host + "/push")
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != 302 || requests.Load() != 1 || dials.Load() != 1 {
		t.Fatal("redirect followed or multiple dials")
	}
	if _, err = client.Get("https://" + host + "/push"); err == nil {
		t.Fatal("DNS rebinding accepted")
	}
	if dials.Load() != 1 {
		t.Fatal("private rebinding reached dialer")
	}
}
