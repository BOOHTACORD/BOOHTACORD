package publicmatrix

import (
	"context"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func TestPublicFixtureSocketNeverSendsCookie(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/public/realtime" || r.URL.RawQuery != "" {
			t.Error("unexpected public target")
		}
		if r.Header.Get("Cookie") != "" {
			t.Error("public socket sent a cookie")
		}
		if r.Header.Get("Origin") == "" {
			t.Error("public origin missing")
		}
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.CloseNow()
		<-ctx.Done()
	}))
	defer server.Close()
	client := server.Client()
	client.Jar, _ = cookiejar.New(nil)
	req, _ := http.NewRequest(http.MethodGet, server.URL, nil)
	client.Jar.SetCookies(req.URL, []*http.Cookie{{Name: "session", Value: "fixture"}})
	conn, err := Open(ctx, client, server.URL)
	if err != nil {
		t.Fatal(err)
	}
	conn.CloseNow()
	cancel()
	if _, err := Open(context.Background(), client, "https://foreign.invalid"); err == nil {
		t.Fatal("foreign target accepted")
	}
}
