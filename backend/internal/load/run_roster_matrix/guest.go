package runrostermatrix

import (
	"context"
	"errors"
	"net/http"
	"time"

	public "voice-platform/backend/internal/load/public_matrix"
	legacy "voice-platform/backend/internal/load/roster_matrix"
)

// StartGuest requires a previously verified disposable fixture and budget.
func StartGuest(parent context.Context, client *http.Client, origin string, index int, baseline bool, measurements *Measurements) (*Actor, error) {
	if client == nil || measurements == nil || index < 0 || index >= 100 {
		return nil, errors.New("invalid guest fixture")
	}
	ctx, cancel := context.WithCancel(parent)
	actor := &Actor{cancel: cancel, failures: make(chan struct{}, 1)}
	started := time.Now()
	observe := func(kind string, elapsed time.Duration) { measurements.Observe(index, kind, elapsed) }
	if baseline {
		body, err := legacy.OpenLegacy(ctx, client, origin, "maintenance")
		if err != nil {
			cancel()
			return nil, errors.New("baseline public stream failed")
		}
		actor.bodies = append(actor.bodies, body)
		actor.run(ctx, func() error { return legacy.ReadLegacy(body, "maintenance", nil, started, observe) })
	} else {
		var err error
		actor.conn, err = public.Open(ctx, client, origin)
		if err != nil {
			cancel()
			return nil, errors.New("candidate public socket failed")
		}
		actor.run(ctx, func() error { return public.Read(ctx, actor.conn, started, observe) })
	}
	return actor, nil
}
