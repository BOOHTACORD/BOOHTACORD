package connectsession

import (
	"context"
	"time"

	"github.com/coder/websocket"
)

func rosterEventsOrNil(roster RosterStream) <-chan RosterDelivery {
	if roster != nil {
		return roster.Events()
	}
	return nil
}

func cancelPendingCheck(cancel *context.CancelFunc) {
	if *cancel != nil {
		(*cancel)()
	}
}

func writeHeartbeat(connection *websocket.Conn, newID Identifier, now Clock) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	return writeEvent(ctx, connection, newID, now, "connection.heartbeat", map[string]any{})
}
