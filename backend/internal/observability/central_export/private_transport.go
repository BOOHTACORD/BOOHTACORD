package centralexport

import (
	"context"
	"errors"
	"net"
	"net/http"
	"time"
)

// Local diagnostic destinations are operator-configured and may have arbitrary
// Docker/service DNS names. Validate every resolved address at dial time; never
// forward raw diagnostics or local ingest authorization to a public address.
func privateCollectorTransport(lookup func(context.Context, string) ([]net.IPAddr, error)) *http.Transport {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.Proxy = nil
	transport.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
		host, port, err := net.SplitHostPort(address)
		if err != nil {
			return nil, err
		}
		ips, err := lookup(ctx, host)
		if err != nil {
			return nil, err
		}
		if len(ips) == 0 {
			return nil, errors.New("local collector unavailable")
		}
		for _, ip := range ips {
			if !(ip.IP.IsPrivate() || ip.IP.IsLoopback()) {
				return nil, errors.New("local collector address is not private")
			}
		}
		return (&net.Dialer{Timeout: 2 * time.Second}).DialContext(ctx, network, net.JoinHostPort(ips[0].IP.String(), port))
	}
	return transport
}
