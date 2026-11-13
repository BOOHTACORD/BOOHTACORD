package observe_resources

import (
	"context"
	"errors"
	"net/http"
	"time"
)

var ErrFaultInactive = errors.New("isolated fault is not active")

func (g Guard) FaultActive(ctx context.Context, name string) error {
	allowed := map[string]bool{"db_pressure": true, "sfu_outage": true, "slow_telemetry": true, "disk_pressure": true}
	if !allowed[name] {
		return errors.New("unknown isolated fault")
	}
	response, err := g.Request(ctx, http.MethodGet, "/fault-status/"+name)
	if err != nil {
		return ErrUnavailable
	}
	defer response.Body.Close()
	if response.StatusCode == http.StatusConflict {
		return ErrFaultInactive
	}
	if response.StatusCode != http.StatusNoContent {
		return ErrDenied
	}
	return nil
}

// WaitFault allows the database fault process time to acquire its lock.
func (g Guard) WaitFault(ctx context.Context, name string) error {
	ctx, cancel := context.WithTimeout(ctx, time.Second)
	defer cancel()
	for {
		err := g.FaultActive(ctx, name)
		if !errors.Is(err, ErrFaultInactive) {
			return err
		}
		select {
		case <-ctx.Done():
			return ErrFaultInactive
		case <-time.After(50 * time.Millisecond):
		}
	}
}
