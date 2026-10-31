package uploadrequest

import (
	"context"
	"errors"
	"net/http"
	"time"
)

func WithLimits(writer http.ResponseWriter, request *http.Request, maximum, idle time.Duration) (*http.Request, func(), error) {
	deadline, err := newReadDeadline(writer, maximum, idle)
	if err != nil {
		return request, func() {}, err
	}
	ctx, cancel := context.WithCancelCause(request.Context())
	body := &boundedBody{source: request.Body, ctx: ctx, cancel: cancel, idle: idle, deadline: deadline}
	ctx = context.WithValue(ctx, timeoutKey{}, &body.expired)
	body.ctx = ctx
	body.timer = time.AfterFunc(idle, func() { body.interrupt(ErrReadTimeout) })
	maximumTimer := time.AfterFunc(maximum, func() { body.interrupt(ErrReadTimeout) })
	stopCancel := context.AfterFunc(request.Context(), func() { body.interrupt(context.Cause(request.Context())) })
	request.Body = body
	return request.WithContext(ctx), func() {
		body.mutex.Lock()
		body.finished = true
		maximumTimer.Stop()
		body.timer.Stop()
		stopCancel()
		body.deadline.clear()
		body.mutex.Unlock()
		cancel(nil)
	}, nil
}

func (body *boundedBody) interrupt(cause error) {
	body.mutex.Lock()
	if body.finished || body.interrupted {
		body.mutex.Unlock()
		return
	}
	if errors.Is(cause, ErrReadTimeout) && time.Now().Before(body.deadline.at) {
		body.mutex.Unlock()
		return
	}
	body.interrupted = true
	body.expired.Store(errors.Is(cause, ErrReadTimeout))
	body.cancel(cause)
	body.deadline.interrupt()
	body.mutex.Unlock()
	_ = body.source.Close()
}
