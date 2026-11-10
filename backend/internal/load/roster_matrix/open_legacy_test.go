package rostermatrix

import (
	"context"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"testing"
)

func TestLegacyComparisonUsesPublicAndPrivateCookieScopes(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, cookieErr := r.Cookie("session")
		switch r.URL.Path {
		case "/api/v1/maintenance/events":
			if cookieErr == nil {
				t.Error("public stream received a cookie")
			}
		case "/api/v1/voice/rosters/events":
			if cookieErr != nil {
				t.Error("roster stream lacks session")
			}
		default:
			t.Error("unexpected legacy path")
		}
		w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
		_, _ = w.Write([]byte("data: {}\n\n"))
	}))
	defer server.Close()
	client := server.Client()
	client.Jar, _ = cookiejar.New(nil)
	req, _ := http.NewRequest(http.MethodGet, server.URL, nil)
	client.Jar.SetCookies(req.URL, []*http.Cookie{{Name: "session", Value: "fixture"}})
	for _, stream := range []string{"maintenance", "roster"} {
		body, err := OpenLegacy(context.Background(), client, server.URL, stream)
		if err != nil {
			t.Fatal(err)
		}
		body.Close()
	}
	if _, err := OpenLegacy(context.Background(), client, server.URL, "other"); err == nil {
		t.Fatal("unknown stream accepted")
	}
}
