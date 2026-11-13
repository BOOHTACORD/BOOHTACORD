package connect_realtime

import (
	"testing"

	"github.com/coder/websocket"
	"voice-platform/backend/internal/load/record_results"
)

func TestReadFailureRecordsSafeCloseStatusOnlyForCurrentSocket(t *testing.T) {
	results := record_results.New()
	s := New(results)
	old, current := &websocket.Conn{}, &websocket.Conn{}
	s.conn = current
	s.recordReadFailure(old, websocket.CloseError{Code: websocket.StatusPolicyViolation})
	if len(results.Snapshot()) != 0 {
		t.Fatal("stale socket altered diagnostics")
	}
	s.recordReadFailure(current, websocket.CloseError{Code: websocket.StatusTryAgainLater, Reason: "private detail"})
	row := results.Snapshot()["ws_close"]
	if row.Count != 1 || row.Statuses[1013] != 1 {
		t.Fatalf("missing bounded close status: %+v", row)
	}
}
