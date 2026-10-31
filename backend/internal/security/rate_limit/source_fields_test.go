package ratelimit

import (
	"net/http"
	"strings"
	"testing"
)

func sourceFromFields(t *testing.T, remote string, fields []string) string {
	t.Helper()
	trusted, err := parseTrustedProxies([]string{"10.0.0.0/8", "2001:db8:1::/48"})
	if err != nil {
		t.Fatal(err)
	}
	request := &http.Request{RemoteAddr: remote,
		Header: http.Header{"X-Forwarded-For": fields}}
	return sourceKey(request, trusted)
}

func TestSourceKeyRepeatedFieldsNearestBoundary(t *testing.T) {
	fields := []string{"203.0.113.9", "192.0.2.9,10.0.0.4"}
	for _, values := range [][]string{fields, {strings.Join(fields, ",")}} {
		if got := sourceFromFields(t, "10.0.0.5:443", values); got != "192.0.2.9" {
			t.Fatalf("source = %q, want nearest untrusted boundary", got)
		}
	}
}

func TestSourceKeyOrderedFieldsMatchCombined(t *testing.T) {
	cases := []struct {
		name, remote string
		fields       []string
		want         string
	}{
		{"missing", "10.0.0.5:443", nil, "10.0.0.5"},
		{"empty", "10.0.0.5:443", []string{""}, "10.0.0.5"},
		{"all_empty", "10.0.0.5:443", []string{"", ""}, "10.0.0.5"},
		{"leading_empty", "10.0.0.5:443", []string{"", "192.0.2.9"}, "192.0.2.9"},
		{"trailing_empty", "10.0.0.5:443", []string{"192.0.2.9", ""}, "10.0.0.5"},
		{"trusted_walk_bad", "10.0.0.5:443", []string{"192.0.2.9", "bad-ip,10.0.0.4"}, "10.0.0.5"},
		{"ignored_bad_left", "10.0.0.5:443", []string{"bad-ip", "192.0.2.9"}, "192.0.2.9"},
		{"all_trusted", "10.0.0.5:443", []string{"10.0.0.3", "10.0.0.4"}, "10.0.0.3"},
		{"ordered_boundary", "10.0.0.5:443", []string{"192.0.2.9", "203.0.113.9"}, "203.0.113.9"},
		{"IPv4_mapped", "10.0.0.5:443", []string{"::ffff:192.0.2.9", "10.0.0.4"}, "192.0.2.9"},
		{"IPv6_normalized", "10.0.0.5:443", []string{"2001:0db8:abcd:0000:0000:0000:0000:0001", "10.0.0.4"}, "2001:db8:abcd::1"},
		{"two_trusted_CIDRs", "[2001:db8:1::5]:443", []string{"192.0.2.9", "10.0.0.4"}, "192.0.2.9"},
		{"untrusted_direct", "192.0.2.4:443", []string{"203.0.113.9", strings.Repeat(" ", 4097)}, "192.0.2.4"},
		{"invalid_peer", "not-address", []string{"192.0.2.9", "10.0.0.4"}, "not-address"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			for _, fields := range [][]string{tc.fields, {strings.Join(tc.fields, ",")}} {
				if got := sourceFromFields(t, tc.remote, fields); got != tc.want {
					t.Fatalf("source = %q, want %q", got, tc.want)
				}
			}
		})
	}
}
