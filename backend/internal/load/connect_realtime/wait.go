package connect_realtime

import (
	"context"
	"errors"
	"time"

	"github.com/coder/websocket"
)

func (s *Socket) signalLocked() {
	close(s.wake)
	s.wake = make(chan struct{})
}

func (s *Socket) markFailed(conn *websocket.Conn) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.conn == conn {
		s.failure = true
		s.signalLocked()
		return true
	}
	return false
}

func (s *Socket) Wait(ctx context.Context, id string, since time.Time) (time.Duration, error) {
	deadline := time.NewTimer(5 * time.Second)
	defer deadline.Stop()
	s.mu.Lock()
	generation := s.generation
	s.mu.Unlock()
	for {
		s.mu.Lock()
		at, ok := s.seen[id]
		sameGeneration := generation == s.generation
		failed := s.failure || !sameGeneration
		wake := s.wake
		s.mu.Unlock()
		if ok && sameGeneration {
			return at.Sub(since), nil
		}
		if failed {
			return 0, errors.New("websocket fanout interrupted")
		}
		select {
		case <-ctx.Done():
			return 0, ctx.Err()
		case <-deadline.C:
			return 0, errors.New("websocket fanout timeout")
		case <-wake:
		}
	}
}
