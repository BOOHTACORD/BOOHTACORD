package connectsession

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"time"

	"github.com/coder/websocket"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func subscriptionChannels(subscription *eventhub.Subscription) (<-chan eventhub.Event, <-chan struct{}) {
	if subscription == nil {
		return nil, nil
	}
	return subscription.Events(), subscription.Overflowed()
}

func maintenanceChannel(maintenance *observestate.Subscription) <-chan observestate.State {
	if maintenance == nil {
		return nil
	}
	return maintenance.Events()
}

func startActivityReader(connection *websocket.Conn, enabled bool) (<-chan struct{}, <-chan struct{}, <-chan struct{}, context.CancelFunc) {
	ctx, cancel := context.WithCancel(context.Background())
	connection.SetReadLimit(1024)
	active, inactive, closed := make(chan struct{}, 1), make(chan struct{}, 1), make(chan struct{})
	go readActivityFrames(ctx, connection, enabled, active, inactive, closed)
	return active, inactive, closed, cancel
}

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

func readActivityFrames(ctx context.Context, connection *websocket.Conn, enabled bool, active, inactive chan<- struct{}, closed chan<- struct{}) {
	defer close(closed)
	for {
		typ, data, err := connection.Read(ctx)
		if err != nil {
			return
		}
		if typ != websocket.MessageText || !enabled || len(data) > 128 {
			continue
		}
		var frame struct {
			Type string `json:"type"`
		}
		decoder := json.NewDecoder(bytes.NewReader(data))
		decoder.DisallowUnknownFields()
		if decoder.Decode(&frame) != nil {
			continue
		}
		var extra any
		if decoder.Decode(&extra) != io.EOF {
			continue
		}
		switch frame.Type {
		case "activity":
			select {
			case active <- struct{}{}:
			default:
			}
		case "inactive":
			select {
			case inactive <- struct{}{}:
			default:
			}
		}
	}
}
