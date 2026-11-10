package runrostermatrix

import (
	"context"
	"errors"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/coder/websocket"
	chat "voice-platform/backend/internal/load/matrix_chat"
	matrix "voice-platform/backend/internal/load/roster_matrix"
	"voice-platform/backend/internal/load/validate_target"
)

type Actor struct {
	cancel   context.CancelFunc
	conn     *websocket.Conn
	bodies   []io.ReadCloser
	failures chan struct{}
	wg       sync.WaitGroup
	client   *http.Client
}

// StartActor requires the caller to validate the manifest and guard ownership first.
func StartActor(parent context.Context, client *http.Client, manifest validate_target.Manifest, index int, legacy bool, measurements *Measurements) (*Actor, error) {
	return StartActorWithMessages(parent, client, manifest, index, legacy, measurements, nil)
}

func StartActorWithMessages(parent context.Context, client *http.Client, manifest validate_target.Manifest, index int, legacy bool, measurements *Measurements, messages *chat.Collector) (*Actor, error) {
	if client == nil || measurements == nil || index < 0 || index >= len(manifest.Accounts) {
		return nil, errors.New("invalid fixture actor")
	}
	ctx, cancel := context.WithCancel(parent)
	actor := &Actor{cancel: cancel, failures: make(chan struct{}, 3), client: client}
	if matrix.Login(ctx, client, manifest.Origin, manifest.Accounts[index]) != nil {
		cancel()
		return nil, errors.New("fixture actor login failed")
	}
	started := time.Now()
	var err error
	if legacy {
		actor.conn, err = matrix.OpenBaseline(ctx, client, manifest.Origin)
	} else {
		actor.conn, err = matrix.OpenCandidate(ctx, client, manifest.Origin)
	}
	if err != nil {
		cancel()
		return nil, errors.New("fixture actor socket failed")
	}
	observe := func(kind string, elapsed time.Duration) {
		measurements.Observe(index, kind, elapsed)
		if messages != nil {
			if kind == "presence" {
				messages.ObservePresence(index)
			}
			if kind == "roster" || kind == "maintenance" {
				messages.ObserveAuxiliary(index, kind)
			}
		}
	}
	var message func(string, time.Time, time.Time)
	if messages != nil {
		message = func(id string, at, occurred time.Time) { messages.ObserveTimed(index, id, at, occurred) }
	}
	actor.run(ctx, func() error {
		return matrix.ReadCandidateWithMessages(ctx, actor.conn, manifest.Voice, started, observe, message)
	})
	if legacy {
		for _, stream := range []string{"maintenance", "roster"} {
			body, openErr := matrix.OpenLegacy(ctx, client, manifest.Origin, stream)
			if openErr != nil {
				actor.Close()
				return nil, errors.New("fixture legacy stream failed")
			}
			actor.bodies = append(actor.bodies, body)
			stream := stream
			actor.run(ctx, func() error { return matrix.ReadLegacy(body, stream, manifest.Voice, started, observe) })
		}
	}
	return actor, nil
}

func (a *Actor) run(ctx context.Context, fn func() error) {
	a.wg.Add(1)
	go func() {
		defer a.wg.Done()
		if fn() != nil && ctx.Err() == nil {
			select {
			case a.failures <- struct{}{}:
			default:
			}
		}
	}()
}

func (a *Actor) Failed() bool {
	select {
	case <-a.failures:
		return true
	default:
		return false
	}
}
func (a *Actor) Close() {
	a.cancel()
	if a.conn != nil {
		a.conn.CloseNow()
	}
	for _, body := range a.bodies {
		body.Close()
	}
	a.wg.Wait()
}
