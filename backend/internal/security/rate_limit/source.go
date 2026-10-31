package ratelimit

import (
	"fmt"
	"net"
	"net/http"
	"strings"
)

const maxForwardedHeaderBytes = 4096
const maxForwardedHops = 32

func parseTrustedProxies(values []string) ([]*net.IPNet, error) {
	trusted := make([]*net.IPNet, 0, len(values))
	for _, value := range values {
		_, network, err := net.ParseCIDR(strings.TrimSpace(value))
		if err != nil {
			return nil, fmt.Errorf("invalid trusted proxy CIDR %q: %w", value, ErrInvalidConfig)
		}
		trusted = append(trusted, network)
	}
	return trusted, nil
}

func sourceKey(request *http.Request, trusted []*net.IPNet) string {
	peer := remoteIP(request.RemoteAddr)
	if peer == nil {
		return request.RemoteAddr
	}
	if !isTrusted(peer, trusted) {
		return peer.String()
	}
	fields := request.Header.Values("X-Forwarded-For")
	if len(fields) == 0 || len(fields) > maxForwardedHops {
		return peer.String()
	}
	bytes := len(fields) - 1
	for _, value := range fields {
		if len(value) > maxForwardedHeaderBytes-bytes {
			return peer.String()
		}
		bytes += len(value)
	}
	forwarded := strings.Join(fields, ",")
	if forwarded == "" {
		return peer.String()
	}
	hops := strings.Split(forwarded, ",")
	if len(hops) > maxForwardedHops {
		return peer.String()
	}
	current := peer
	for index := len(hops) - 1; index >= 0 && isTrusted(current, trusted); index-- {
		candidate := net.ParseIP(strings.TrimSpace(hops[index]))
		if candidate == nil {
			return peer.String()
		}
		current = candidate
	}
	return current.String()
}

func remoteIP(remote string) net.IP {
	host, _, err := net.SplitHostPort(remote)
	if err != nil {
		host = strings.Trim(remote, "[]")
	}
	return net.ParseIP(host)
}

func isTrusted(address net.IP, trusted []*net.IPNet) bool {
	for _, network := range trusted {
		if network.Contains(address) {
			return true
		}
	}
	return false
}
