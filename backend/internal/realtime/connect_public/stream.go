package connectpublic

import (
	"context"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"github.com/google/uuid"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	"voice-platform/backend/internal/realtime/heartbeat"
)

type event struct {
	ID         string         `json:"event_id"`
	Kind       string         `json:"kind"`
	OccurredAt time.Time      `json:"occurred_at"`
	Payload    map[string]any `json:"payload"`
}

func serve(connection *websocket.Conn, sub *observestate.Subscription, now func() time.Time) {
	closed := connection.CloseRead(context.Background()).Done()
	heartbeats, stopHeartbeat := heartbeat.Ticks(connection)
	defer stopHeartbeat()
	if !write(connection, now, "connection.ready", map[string]any{}) {
		return
	}
	initial := time.NewTimer(2 * time.Second)
	defer initial.Stop()
	first := true
	for {
		select {
		case <-closed:
			return
		case <-heartbeats:
			if !write(connection, now, "connection.heartbeat", map[string]any{}) {
				return
			}
		case <-initial.C:
			if first {
				return
			}
		case state, ok := <-sub.Events():
			if !ok || !state.Known || state.Revision == 0 || state.Revision > 9007199254740991 {
				return
			}
			kind := "maintenance.changed"
			if first {
				kind = "maintenance.snapshot"
				first = false
				initial.Stop()
			}
			payload := map[string]any{"version": 1, "generation": state.Generation, "revision": state.Revision, "active": state.Active}
			if !write(connection, now, kind, payload) {
				return
			}
		}
	}
}

func write(connection *websocket.Conn, now func() time.Time, kind string, payload map[string]any) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	return wsjson.Write(ctx, connection, event{ID: uuid.NewString(), Kind: kind, OccurredAt: now().UTC(), Payload: payload}) == nil
}
