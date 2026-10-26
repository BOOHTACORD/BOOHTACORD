package webpush

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"net"
	"net/http"
	"strings"
	"time"
)

type dialFunc func(context.Context, string, string) (net.Conn, error)
type safeTransport struct {
	gate  Gate
	dial  dialFunc
	roots *x509.CertPool
}

func NewHTTPClient(gate Gate) *http.Client {
	dialer := &net.Dialer{Timeout: 3 * time.Second}
	return &http.Client{Timeout: 5 * time.Second, Transport: &safeTransport{gate: gate, dial: dialer.DialContext}, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
}
func (t *safeTransport) RoundTrip(request *http.Request) (*http.Response, error) {
	target, addresses, err := t.gate.resolve(request.Context(), request.URL.String())
	if err != nil {
		return nil, ErrEndpoint
	}
	if request.Host != "" && !strings.EqualFold(request.Host, target.Host) {
		return nil, ErrEndpoint
	}
	transport := &http.Transport{Proxy: nil, DisableKeepAlives: true, TLSHandshakeTimeout: 3 * time.Second, ResponseHeaderTimeout: 3 * time.Second, MaxResponseHeaderBytes: 16 << 10,
		TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS12, ServerName: target.Hostname(), RootCAs: t.roots}}
	transport.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
		if !strings.EqualFold(address, net.JoinHostPort(target.Hostname(), "443")) {
			return nil, ErrEndpoint
		}
		for _, ip := range addresses {
			connection, err := t.dial(ctx, "tcp", net.JoinHostPort(ip.Unmap().String(), "443"))
			if err == nil {
				return connection, nil
			}
			if ctx.Err() != nil {
				break
			}
		}
		return nil, ErrEndpoint
	}
	response, err := transport.RoundTrip(request)
	if err != nil {
		transport.CloseIdleConnections()
	}
	return response, err
}
