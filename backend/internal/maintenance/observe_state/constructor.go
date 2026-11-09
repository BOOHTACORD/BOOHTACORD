package observestate

import (
	"time"

	"github.com/google/uuid"
)

// NewWithReadObserver observes only completed read outcomes, without error data.
func NewWithReadObserver(reader Reader, interval, timeout time.Duration, report func(bool)) *Observer {
	if interval <= 0 {
		interval = 5 * time.Second
	}
	if timeout <= 0 {
		timeout = 3 * time.Second
	}
	return &Observer{reader: reader, interval: interval, timeout: timeout, readObserver: report,
		state: State{Generation: uuid.NewString()}, subscribers: make(map[*Subscription]struct{}), refresh: make(chan struct{}, 1)}
}
