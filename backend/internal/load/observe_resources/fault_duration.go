package observe_resources

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"time"
)

// FaultFor holds an isolated fault for the phase plus a bounded setup margin.
func (g Guard) FaultFor(ctx context.Context, name string, duration time.Duration) error {
	allowed := map[string]bool{"db_pressure": true, "sfu_outage": true, "slow_telemetry": true, "disk_pressure": true}
	if !allowed[name] || duration <= 0 || duration > 27*time.Second {
		return errors.New("fault duration or name is outside the safe bound")
	}
	if _, err := g.Check(ctx); err != nil {
		return err
	}
	seconds := int((duration+time.Second-1)/time.Second) + 3
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, g.Manifest.Guard+"/fault/"+name, nil)
	if err != nil {
		return ErrUnavailable
	}
	req.Header.Set("X-Load-Nonce", g.Manifest.Nonce)
	req.Header.Set("X-QA-Fault-Seconds", strconv.Itoa(seconds))
	response, err := g.Client.Do(req)
	if err != nil {
		return ErrUnavailable
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusNoContent {
		return ErrDenied
	}
	return nil
}
