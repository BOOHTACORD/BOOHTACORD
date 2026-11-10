package publicmatrix

import (
	"context"
	"errors"
	"time"

	"github.com/coder/websocket"
)

func Read(ctx context.Context, conn *websocket.Conn, started time.Time, observe func(string, time.Duration)) error {
	conn.SetReadLimit(4096)
	ready, snapshot := false, false
	for {
		_, frame, err := conn.Read(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
		kind, err := Classify(frame)
		if err != nil {
			return err
		}
		switch kind {
		case "ready":
			if ready || snapshot {
				return errors.New("unexpected public ready order")
			}
			ready = true
		case "maintenance":
			if !ready || snapshot {
				return errors.New("unexpected public snapshot order")
			}
			snapshot = true
		case "changed":
			if !snapshot {
				return errors.New("public change before snapshot")
			}
		}
		observe(kind, time.Since(started))
	}
}
