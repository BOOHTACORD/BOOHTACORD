package connectsession

import (
	"context"
	"time"

	"github.com/coder/websocket"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
)

func writeMaintenance(connection *websocket.Conn, state observestate.State, first bool, newID Identifier, now Clock) bool {
	if !state.Known || state.Revision == 0 || state.Revision > 9007199254740991 {
		return false
	}
	kind := "maintenance.changed"
	if first {
		kind = "maintenance.snapshot"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return writeEvent(ctx, connection, newID, now, kind, map[string]any{"version": 1, "generation": state.Generation, "revision": state.Revision, "active": state.Active})
}
