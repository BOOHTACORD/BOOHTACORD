package connect_realtime

import (
	"errors"

	"github.com/coder/websocket"
)

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
	s.results.ObserveOutcome(closeCategory(err), status, 0, false)
}

func closeCategory(err error) string {
	var closeErr websocket.CloseError
	if errors.As(err, &closeErr) && closeErr.Code == websocket.StatusTryAgainLater {
		switch closeErr.Reason {
		case "session verification unavailable":
			return "ws_close_session_unavailable"
		case "realtime resynchronization required":
			return "ws_close_resync_required"
		case "roster unavailable":
			return "ws_close_roster_unavailable"
		}
	}
	return "ws_close_other"
}
