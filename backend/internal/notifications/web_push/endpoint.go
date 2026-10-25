package webpush

import (
	"context"
	"errors"
	"net"
	"net/netip"
	"net/url"
	"strings"
	"time"
)

var ErrEndpoint = errors.New("notification endpoint unavailable")

type Resolver interface {
	LookupNetIP(context.Context, string, string) ([]netip.Addr, error)
}
type Gate struct {
	hosts    map[string]bool
	resolver Resolver
}

func NewGate(hosts []string, resolver Resolver) (Gate, error) {
	if resolver == nil {
		resolver = net.DefaultResolver
	}
	if len(hosts) == 0 || len(hosts) > 32 {
		return Gate{}, ErrEndpoint
	}
	gate := Gate{hosts: make(map[string]bool), resolver: resolver}
	for _, host := range hosts {
		host = strings.ToLower(host)
		if len(host) > 253 || host == "" || strings.ContainsAny(host, "/:@%\\* ") || strings.HasSuffix(host, ".") {
			return Gate{}, ErrEndpoint
		}
		if _, err := netip.ParseAddr(host); err == nil {
			return Gate{}, ErrEndpoint
		}
		gate.hosts[host] = true
	}
	return gate, nil
}
func (g Gate) Validate(ctx context.Context, endpoint string) error {
	_, _, err := g.resolve(ctx, endpoint)
	return err
}
func (g Gate) resolve(ctx context.Context, endpoint string) (*url.URL, []netip.Addr, error) {
	if len(endpoint) == 0 || len(endpoint) > 2048 {
		return nil, nil, ErrEndpoint
	}
	u, err := url.Parse(endpoint)
	if err != nil || u.Scheme != "https" || u.User != nil || u.Fragment != "" || u.Opaque != "" || !g.hosts[strings.ToLower(u.Hostname())] || u.Port() != "" && u.Port() != "443" {
		return nil, nil, ErrEndpoint
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	addresses, err := g.resolver.LookupNetIP(ctx, "ip", u.Hostname())
	if err != nil || len(addresses) == 0 || len(addresses) > 16 {
		return nil, nil, ErrEndpoint
	}
	for _, address := range addresses {
		if !publicAddress(address) {
			return nil, nil, ErrEndpoint
		}
	}
	return u, addresses, nil
}

var deniedPrefixes = []netip.Prefix{
	netip.MustParsePrefix("0.0.0.0/8"), netip.MustParsePrefix("10.0.0.0/8"), netip.MustParsePrefix("100.64.0.0/10"), netip.MustParsePrefix("127.0.0.0/8"),
	netip.MustParsePrefix("169.254.0.0/16"), netip.MustParsePrefix("172.16.0.0/12"), netip.MustParsePrefix("192.0.0.0/24"), netip.MustParsePrefix("192.0.2.0/24"),
	netip.MustParsePrefix("192.168.0.0/16"), netip.MustParsePrefix("192.88.99.0/24"), netip.MustParsePrefix("198.18.0.0/15"), netip.MustParsePrefix("198.51.100.0/24"),
	netip.MustParsePrefix("203.0.113.0/24"), netip.MustParsePrefix("224.0.0.0/4"), netip.MustParsePrefix("240.0.0.0/4"),
	netip.MustParsePrefix("2001::/23"), netip.MustParsePrefix("2001:db8::/32"), netip.MustParsePrefix("2002::/16"),
}

func publicAddress(raw netip.Addr) bool {
	if !raw.IsValid() || raw.Zone() != "" {
		return false
	}
	ip := raw.Unmap()
	if !ip.IsGlobalUnicast() || ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast() {
		return false
	}
	if ip.Is6() && !netip.MustParsePrefix("2000::/3").Contains(ip) {
		return false
	}
	for _, prefix := range deniedPrefixes {
		if prefix.Contains(ip) {
			return false
		}
	}
	return true
}
