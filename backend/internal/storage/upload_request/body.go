package uploadrequest

import (
	"context"
	"errors"
	"io"
	"sync"
	"sync/atomic"
	"time"
)

var ErrReadTimeout = errors.New("upload body read deadline exceeded")

type timeoutKey struct{}

func TimedOut(ctx context.Context) bool {
	state, _ := ctx.Value(timeoutKey{}).(*atomic.Bool)
	return state != nil && state.Load() || errors.Is(context.Cause(ctx), ErrReadTimeout)
}

type boundedBody struct {
	source      io.ReadCloser
	ctx         context.Context
	cancel      context.CancelCauseFunc
	mutex       sync.Mutex
	timer       *time.Timer
	idle        time.Duration
	deadline    *readDeadline
	expired     atomic.Bool
	finished    bool
	interrupted bool
}

func (body *boundedBody) Read(buffer []byte) (int, error) {
	if cause := context.Cause(body.ctx); cause != nil {
		return 0, cause
	}
	count, err := body.source.Read(buffer)
	body.mutex.Lock()
	defer body.mutex.Unlock()
	if body.expired.Load() {
		return count, ErrReadTimeout
	}
	if cause := context.Cause(body.ctx); cause != nil {
		return count, cause
	}
	if count > 0 && !body.finished {
		body.deadline.advance()
		body.timer.Reset(body.idle)
	}
	return count, err
}

func (body *boundedBody) Close() error {
	err := body.source.Close()
	body.timer.Stop()
	return err
}
