package connect_realtime

import (
	"testing"

	"github.com/coder/websocket"
	"voice-platform/backend/internal/load/record_results"
)

func TestCloseDiagnosticsUseOnlyFixedPrivacySafeCategories(t *testing.T) {
	cases := []struct{ reason, category string }{
		{"session verification unavailable", "ws_close_session_unavailable"},
		{"realtime resynchronization required", "ws_close_resync_required"},
		{"roster unavailable", "ws_close_roster_unavailable"},
		{"private account and token", "ws_close_other"},
	}
	for _, tc := range cases {
		results := record_results.New()
		socket := New(results)
		connection := &websocket.Conn{}
		socket.conn = connection
		socket.recordReadFailure(connection, websocket.CloseError{
			Code: websocket.StatusTryAgainLater, Reason: tc.reason,
		})
		rows := results.Snapshot()
		if len(rows) != 2 || rows["ws_close"].Count != 1 || rows[tc.category].Count != 1 {
			t.Fatalf("incorrect fixed diagnostic categories: %v", rows)
		}
	}
}
