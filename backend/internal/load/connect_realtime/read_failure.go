package connect_realtime

import "github.com/coder/websocket"

// Record only a bounded close-code category, never the server's close reason.
func (s *Socket) recordReadFailure(conn *websocket.Conn, err error) {
	if !s.markFailed(conn) {
		return
	}
	status := 0
	switch code := websocket.CloseStatus(err); code {
	case websocket.StatusNormalClosure, websocket.StatusGoingAway,
		websocket.StatusPolicyViolation, websocket.StatusInternalError,
		websocket.StatusTryAgainLater:
		status = int(code)
	}
	s.results.ObserveOutcome("ws_close", status, 0, false)
}
