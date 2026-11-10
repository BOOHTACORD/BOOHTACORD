package connectpublic

import (
	"context"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	observestate "voice-platform/backend/internal/maintenance/observe_state"
	admitpublic "voice-platform/backend/internal/realtime/admit_public_connection"
	ratelimit "voice-platform/backend/internal/security/rate_limit"
)

type publicCounts struct{ opened, closed atomic.Int32 }

func (c *publicCounts) PublicRealtimeConnectionOpened() { c.opened.Add(1) }
func (c *publicCounts) PublicRealtimeConnectionClosed() { c.closed.Add(1) }

func TestPublicConnectionObserverCountsAcceptedAndClosedOnly(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	state := observestate.New(&reader{}, time.Hour, time.Second)
	go state.Run(ctx)
	rate, _ := ratelimit.New(ratelimit.Config{Limit: 100, Window: time.Minute, MaxSources: 100})
	quota, _ := admitpublic.New(admitpublic.Config{GlobalLimit: 20, SourceLimit: 20})
	counts := &publicCounts{}
	handler, err := New("https://voice.example.test", state, rate, quota, counts)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(handler)
	defer server.Close()
	_, response, err := dial(t, server, "https://foreign.invalid", "")
	if err == nil || response == nil {
		t.Fatal("foreign origin accepted")
	}
	if counts.opened.Load() != 0 {
		t.Fatal("rejected handshake counted")
	}
	socket, _, err := dial(t, server, "https://voice.example.test", "")
	if err != nil {
		t.Fatal(err)
	}
	read(t, socket)
	if counts.opened.Load() != 1 {
		t.Fatal("accepted connection not counted")
	}
	socket.CloseNow()
	deadline := time.Now().Add(2 * time.Second)
	for counts.closed.Load() == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if counts.closed.Load() != 1 {
		t.Fatal("closed connection not counted")
	}
}
