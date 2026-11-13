package connect_realtime

import (
	"github.com/coder/websocket"
	"time"
)

func (s *Socket) apply(conn *websocket.Conn, event Event, replay bool) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.conn != conn {
		return false
	}
	if event.Kind == "connection.resync_required" {
		s.resync = true
		s.results.Observe("resync", 200, 0)
	}
	if event.Kind == "message.created" {
		s.last = event.ID
		if !s.remember(event.Payload.MessageID, time.Now()) {
			s.failure = true
			s.signalLocked()
			return false
		}
		if replay {
			s.results.Observe("replay", 200, 0)
		}
	}
	s.signalLocked()
	return true
}
