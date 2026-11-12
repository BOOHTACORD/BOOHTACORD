// Package heartbeat provides the negotiated, payload-free liveness interval.
package heartbeat

import (
	"time"

	"github.com/coder/websocket"
)

const Protocol = "boohtacord.heartbeat.v1"
const Interval = 15 * time.Second

func Ticks(connection *websocket.Conn) (<-chan time.Time, func()) {
	if connection.Subprotocol() != Protocol {
		return nil, func() {}
	}
	ticker := time.NewTicker(Interval)
	return ticker.C, ticker.Stop
}
