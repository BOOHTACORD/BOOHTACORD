package connect_realtime

import (
	"testing"

	"github.com/coder/websocket"
	"voice-platform/backend/internal/load/record_results"
)

func TestFailureStatusIgnoresStaleSocketAndTracksCurrentFailure(t *testing.T) {
	s := New(record_results.New())
	old, current := &websocket.Conn{}, &websocket.Conn{}
	s.conn = current
	if s.Failed() {
		t.Fatal("fresh socket marked failed")
	}
	s.markFailed(old)
	if s.Failed() {
		t.Fatal("stale failure changed current status")
	}
	s.markFailed(current)
	if !s.Failed() {
		t.Fatal("current failure was not reported")
	}
}
