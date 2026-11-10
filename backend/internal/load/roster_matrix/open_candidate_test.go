package rostermatrix

import (
	"context"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func TestCandidateConnectsWithCapabilitiesAndSession(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/realtime" || !strings.Contains(r.URL.Query().Get("capabilities"), "voice_roster_v1") || !strings.Contains(r.URL.Query().Get("capabilities"), "maintenance_v1") || !strings.Contains(r.URL.Query().Get("capabilities"), "notifications_v1") {
			t.Error("missing candidate capability")
		}
		if r.Header.Get("Origin") == "" {
			t.Error("missing Origin")
		}
		if _, err := r.Cookie("session"); err != nil {
			t.Error("missing synthetic session")
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
	conn, err := OpenCandidate(ctx, client, server.URL)
	if err != nil {
		t.Fatal(err)
	}
	conn.CloseNow()
	cancel()
}

func TestBaselineSocketUsesOnlyExistingCapabilities(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		caps := r.URL.Query().Get("capabilities")
		if strings.Contains(caps, "voice_roster_v1") || strings.Contains(caps, "maintenance_v1") || !strings.Contains(caps, "notifications_v1") {
			t.Error("incorrect baseline capabilities")
		}
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.CloseNow()
		<-ctx.Done()
	}))
	defer server.Close()
	conn, err := OpenBaseline(ctx, server.Client(), server.URL)
	if err != nil {
		t.Fatal(err)
	}
	conn.CloseNow()
	cancel()
}
