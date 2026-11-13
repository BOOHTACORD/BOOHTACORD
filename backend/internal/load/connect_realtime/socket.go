package connect_realtime

import (
	"context"
	"errors"
	"github.com/coder/websocket"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
	"voice-platform/backend/internal/load/record_results"
)

type Event struct {
	ID      string `json:"event_id"`
	Kind    string `json:"kind"`
	Payload struct {
		MessageID string `json:"message_id"`
	} `json:"payload"`
}
type Socket struct {
	mu         sync.Mutex
	conn       *websocket.Conn
	cancel     context.CancelFunc
	last       string
	seen       map[string]time.Time
	order      []string
	tracked    map[string]int
	wake       chan struct{}
	generation uint64
	failure    bool
	resync     bool
	results    *record_results.Results
}

func New(results *record_results.Results) *Socket {
	return &Socket{seen: map[string]time.Time{}, tracked: map[string]int{}, wake: make(chan struct{}), results: results}
}
func (s *Socket) Connect(ctx context.Context, client *http.Client, origin string, resume bool) error {
	s.Close()
	s.mu.Lock()
	last := s.last
	s.resync = false
	s.mu.Unlock()
	address := strings.Replace(origin, "https://", "wss://", 1) + "/api/v1/realtime"
	if resume && last != "" {
		address += "?after=" + url.QueryEscape(last)
	}
	started := time.Now()
	conn, response, err := websocket.Dial(ctx, address, &websocket.DialOptions{HTTPClient: client, HTTPHeader: http.Header{"Origin": {origin}}})
	if err != nil {
		if response != nil {
			response.Body.Close()
		}
		s.results.Observe("ws_ready", 503, time.Since(started))
		return errors.New("websocket upgrade failed")
	}
	conn.SetReadLimit(65536)
	readCtx, cancel := context.WithCancel(ctx)
	s.mu.Lock()
	s.conn = conn
	s.cancel = cancel
	s.failure = false
	s.mu.Unlock()
	ready := make(chan bool, 1)
	go s.read(readCtx, conn, ready, resume)
	select {
	case ok := <-ready:
		if !ok {
			return errors.New("websocket closed before ready")
		}
		s.results.Observe("ws_ready", 200, time.Since(started))
		return nil
	case <-ctx.Done():
		s.Close()
		return ctx.Err()
	case <-time.After(5 * time.Second):
		s.Close()
		return errors.New("websocket ready timeout")
	}
}
func (s *Socket) Resync() bool { s.mu.Lock(); defer s.mu.Unlock(); return s.resync }
func (s *Socket) Close() {
	s.mu.Lock()
	conn, cancel := s.conn, s.cancel
	s.conn = nil
	s.cancel = nil
	s.generation++
	s.tracked = map[string]int{}
	s.failure = true
	s.signalLocked()
	s.mu.Unlock()
	if cancel != nil {
		cancel()
	}
	if conn != nil {
		conn.CloseNow()
	}
}
