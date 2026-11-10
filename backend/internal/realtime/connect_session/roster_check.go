package connectsession

import "context"

type rosterCheckResult struct {
	delivery RosterDelivery
	version  uint64
	err      error
}

func startRosterCheck(stream RosterStream, delivery RosterDelivery, version uint64) (<-chan rosterCheckResult, context.CancelFunc) {
	ctx, cancel := context.WithCancel(context.Background())
	result := make(chan rosterCheckResult, 1)
	go func() {
		err := stream.Check(ctx, delivery.State)
		select {
		case result <- rosterCheckResult{delivery: delivery, version: version, err: err}:
		case <-ctx.Done():
		}
	}()
	return result, cancel
}
