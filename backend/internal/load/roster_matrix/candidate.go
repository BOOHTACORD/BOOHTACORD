package rostermatrix

import (
	"context"
	"time"

	"github.com/coder/websocket"
)

// ReadCandidate consumes the actual application socket until cancellation.
func ReadCandidate(ctx context.Context, conn *websocket.Conn, rooms []string, started time.Time, observe func(string, time.Duration)) error {
	return ReadCandidateWithMessages(ctx, conn, rooms, started, observe, nil)
}

// ReadCandidateWithMessages also records message hints from the same socket.
func ReadCandidateWithMessages(ctx context.Context, conn *websocket.Conn, rooms []string, started time.Time, observe func(string, time.Duration), message func(string, time.Time, time.Time)) error {
	conn.SetReadLimit(512 << 10)
	for {
		_, frame, err := conn.Read(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
		kind, err := CandidateEvent(frame, rooms)
		if err != nil {
			return err
		}
		if kind != "" {
			observe(kind, time.Since(started))
		}
		if message != nil {
			id, err := MessageID(frame)
			if err != nil {
				return err
			}
			if id != "" {
				occurred, err := MessageOccurredAt(frame)
				if err != nil {
					return err
				}
				message(id, time.Now(), occurred)
			}
		}
	}
}
