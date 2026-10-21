package centralexport

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestPrivateCollectorAliasWorksButPublicAndMixedDNSFailClosed(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(204) }))
	defer server.Close()
	_, port, _ := net.SplitHostPort(server.Listener.Addr().String())
	for _, test := range []struct {
		name    string
		ips     []net.IPAddr
		allowed bool
	}{
		{"private-alias", []net.IPAddr{{IP: net.ParseIP("127.0.0.1")}}, true},
		{"public", []net.IPAddr{{IP: net.ParseIP("203.0.113.1")}}, false},
		{"mixed", []net.IPAddr{{IP: net.ParseIP("127.0.0.1")}, {IP: net.ParseIP("203.0.113.1")}}, false},
	} {
		t.Run(test.name, func(t *testing.T) {
			transport := privateCollectorTransport(func(context.Context, string) ([]net.IPAddr, error) { return test.ips, nil })
			defer transport.CloseIdleConnections()
			client := &http.Client{Transport: transport}
			response, err := client.Get("http://qa-client-synthetic-tempo:" + port + "/v1/traces")
			if test.allowed {
				if err != nil {
					t.Fatal("owned private collector alias rejected")
				}
				response.Body.Close()
				if response.StatusCode != 204 {
					t.Fatal("wrong collector")
				}
			} else if err == nil {
				response.Body.Close()
				t.Fatal("raw diagnostics could leave private boundary")
			}
		})
	}
}
