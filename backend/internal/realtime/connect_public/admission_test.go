package connectpublic

import (
	"net/http"
	"testing"
	"time"

	"github.com/coder/websocket"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	admitpublic "voice-platform/backend/internal/realtime/admit_public_connection"
	ratelimit "voice-platform/backend/internal/security/rate_limit"
)

func TestRejectsRateExhaustion(t *testing.T) {
	server, _, _ := setup(t, 1)
	first, _, err := dial(t, server, "", "")
	if err != nil {
		t.Fatal(err)
	}
	defer first.CloseNow()
	second, response, err := dial(t, server, "", "")
	if err == nil {
		second.CloseNow()
		t.Fatal("rate limit bypassed")
	}
	if response == nil || response.StatusCode != http.StatusTooManyRequests {
		t.Fatalf("response: %+v", response)
	}
}

func TestQuotaAllowsTwentyAndRejectsTwentyFirst(t *testing.T) {
	server, _, _ := setup(t, 100)
	var sockets []*websocket.Conn
	defer func() {
		for _, socket := range sockets {
			socket.CloseNow()
		}
	}()
	for i := 0; i < 20; i++ {
		socket, _, err := dial(t, server, "", "")
		if err != nil {
			t.Fatalf("connection %d: %v", i+1, err)
		}
		sockets = append(sockets, socket)
	}
	socket, response, err := dial(t, server, "", "")
	if err == nil {
		socket.CloseNow()
		t.Fatal("quota bypassed")
	}
	if response == nil || response.StatusCode != http.StatusTooManyRequests {
		t.Fatalf("response: %+v", response)
	}
}

func TestRejectsInvalidDependenciesAndOrigins(t *testing.T) {
	observer := observestate.New(&reader{}, time.Second, time.Second)
	rate, _ := ratelimit.New(ratelimit.Config{Limit: 1, Window: time.Minute, MaxSources: 1})
	quota, _ := admitpublic.New(admitpublic.Config{GlobalLimit: 20, SourceLimit: 20})
	for _, origin := range []string{"", "https://voice.example.test/", "https://user@voice.example.test", "https://voice.example.test?x=1"} {
		if _, err := New(origin, observer, rate, quota); err == nil {
			t.Fatalf("accepted %q", origin)
		}
	}
	if _, err := New("https://voice.example.test", nil, rate, quota); err == nil {
		t.Fatal("accepted nil observer")
	}
	if _, err := New("https://voice.example.test", observer, nil, quota); err == nil {
		t.Fatal("accepted nil rate limiter")
	}
	if _, err := New("https://voice.example.test", observer, rate, nil); err == nil {
		t.Fatal("accepted nil quota")
	}
}
