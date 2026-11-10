package connectpublic

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	admitpublic "voice-platform/backend/internal/realtime/admit_public_connection"
	ratelimit "voice-platform/backend/internal/security/rate_limit"
)

type reader struct{ mode atomic.Int32 }

func (r *reader) Active(context.Context) (bool, error) {
	switch r.mode.Load() {
	case 1:
		return true, nil
	case 2:
		return false, errors.New("private error")
	}
	return false, nil
}

func setup(t *testing.T, limit int) (*httptest.Server, *observestate.Observer, *reader) {
	t.Helper()
	r := &reader{}
	observer := observestate.New(r, time.Hour, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	go observer.Run(ctx)
	rate, err := ratelimit.New(ratelimit.Config{Limit: limit, Window: time.Minute, MaxSources: 100})
	if err != nil {
		t.Fatal(err)
	}
	quota, err := admitpublic.New(admitpublic.Config{GlobalLimit: 20, SourceLimit: 20})
	if err != nil {
		t.Fatal(err)
	}
	handler, err := New("https://voice.example.test", observer, rate, quota)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(handler)
	t.Cleanup(func() { server.Close(); cancel() })
	return server, observer, r
}

func dial(t *testing.T, server *httptest.Server, origin, query string) (*websocket.Conn, *http.Response, error) {
	t.Helper()
	h := http.Header{}
	if origin != "" {
		h.Set("Origin", origin)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	return websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+query, &websocket.DialOptions{HTTPHeader: h})
}

type frame struct {
	Kind    string         `json:"kind"`
	Payload map[string]any `json:"payload"`
}

func read(t *testing.T, socket *websocket.Conn) frame {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	var value frame
	if err := wsjson.Read(ctx, socket, &value); err != nil {
		t.Fatal(err)
	}
	return value
}
