package connectpublic

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	admitpublic "voice-platform/backend/internal/realtime/admit_public_connection"
	ratelimit "voice-platform/backend/internal/security/rate_limit"
)

func TestUntrustedForwardedHeadersCannotEvadeSourceQuota(t *testing.T) {
	observer := observestate.New(&reader{}, time.Hour, time.Second)
	ctx, stop := context.WithCancel(context.Background())
	go observer.Run(ctx)
	t.Cleanup(stop)
	rate, err := ratelimit.New(ratelimit.Config{Limit: 100, Window: time.Minute, MaxSources: 100})
	if err != nil {
		t.Fatal(err)
	}
	quota, err := admitpublic.New(admitpublic.Config{GlobalLimit: 40, SourceLimit: 20})
	if err != nil {
		t.Fatal(err)
	}
	handler, err := New("https://voice.example.test", observer, rate, quota)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(handler)
	t.Cleanup(server.Close)
	var connections []*websocket.Conn
	defer func() {
		for _, conn := range connections {
			conn.CloseNow()
		}
	}()
	for index := 0; index < 21; index++ {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		header := http.Header{"X-Forwarded-For": {fmt.Sprintf("192.0.2.%d", index+1)}}
		conn, response, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: header})
		cancel()
		if index < 20 {
			if err != nil {
				t.Fatalf("connection %d unexpectedly rejected: %v", index+1, err)
			}
			connections = append(connections, conn)
			continue
		}
		if conn != nil {
			conn.CloseNow()
		}
		if err == nil || response == nil || response.StatusCode != http.StatusTooManyRequests {
			t.Fatalf("forged forwarding bypassed quota: response=%v error=%v", response, err)
		}
	}
}
