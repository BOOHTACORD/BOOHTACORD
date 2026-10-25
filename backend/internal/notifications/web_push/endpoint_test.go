package webpush

import (
	"context"
	"net/netip"
	"testing"
)

type resolverStub struct{ addresses []netip.Addr }

func (r resolverStub) LookupNetIP(context.Context, string, string) ([]netip.Addr, error) {
	return r.addresses, nil
}
func TestEndpointRejectsSSRFVariants(t *testing.T) {
	public := resolverStub{[]netip.Addr{netip.MustParseAddr("8.8.8.8")}}
	gate, err := NewGate([]string{"push.example.invalid"}, public)
	if err != nil {
		t.Fatal(err)
	}
	for _, endpoint := range []string{"http://push.example.invalid/x", "https://push.example.invalid.evil/x", "https://evilpush.example.invalid/x", "https://user@push.example.invalid/x", "https://push.example.invalid:444/x", "https://127.0.0.1/x", "https://[::1]/x", "https://2130706433/x", "https://push.example.invalid/x#secret", "https://push.example.invalid./x"} {
		if err := gate.Validate(context.Background(), endpoint); err == nil {
			t.Fatalf("accepted %s", endpoint)
		}
	}
	if err := gate.Validate(context.Background(), "https://push.example.invalid/opaque"); err != nil {
		t.Fatal(err)
	}
}
func TestEveryDNSAnswerMustBePublic(t *testing.T) {
	for _, ip := range []string{"127.0.0.1", "10.1.1.1", "100.64.1.1", "169.254.169.254", "192.168.1.1", "198.18.0.1", "::1", "fe80::1", "fc00::1", "::ffff:127.0.0.1", "2002:7f00:1::", "2001:db8::1"} {
		gate, _ := NewGate([]string{"push.example.invalid"}, resolverStub{[]netip.Addr{netip.MustParseAddr("8.8.8.8"), netip.MustParseAddr(ip)}})
		if err := gate.Validate(context.Background(), "https://push.example.invalid/x"); err == nil {
			t.Fatalf("mixed DNS accepted %s", ip)
		}
	}
}
