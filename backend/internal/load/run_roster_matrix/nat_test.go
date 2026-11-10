package runrostermatrix

import (
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
)

func TestSameSourceUsesIndependentCookieJars(t *testing.T) {
	addresses := make(chan string, 20)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip, _, _ := net.SplitHostPort(r.RemoteAddr)
		addresses <- ip
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()
	u, _ := url.Parse(server.URL)
	for i := 0; i < 20; i++ {
		client := actorClient(i, true)
		if len(client.Jar.Cookies(u)) != 0 {
			t.Fatal("cookie jar was shared")
		}
		client.Jar.SetCookies(u, []*http.Cookie{{Name: "fixture", Value: "private"}})
		response, err := client.Get(server.URL)
		if err != nil {
			t.Fatal(err)
		}
		response.Body.Close()
	}
	first := <-addresses
	for i := 1; i < 20; i++ {
		if ip := <-addresses; ip != first {
			t.Fatal("clients did not share one source IP")
		}
	}
}
