package main

import (
	"context"
	"io"
	"sync"
	"time"
)

func wait(ctx context.Context, duration time.Duration) bool {
	timer := time.NewTimer(duration)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-timer.C:
		return true
	}
}

// Preserve the actual upgraded stream and all its bytes; delay only first read.
type delayedBody struct {
	io.ReadWriteCloser
	ctx         context.Context
	once        sync.Once
	sample      *sample
	cancelled   bool
	setup       sync.Once
	closing     sync.Once
	closeSignal chan struct{}
	frames      closeFrameWatch
}

func (b *delayedBody) prepare() { b.setup.Do(func() { b.closeSignal = make(chan struct{}) }) }
func (b *delayedBody) Write(p []byte) (int, error) {
	b.prepare()
	if b.frames.feed(p) {
		b.closing.Do(func() { close(b.closeSignal) })
	}
	return b.ReadWriteCloser.Write(p)
}

func (b *delayedBody) Read(p []byte) (int, error) {
	b.prepare()
	b.once.Do(func() {
		timer := time.NewTimer(20 * time.Second)
		defer timer.Stop()
		interrupted := true
		select {
		case <-b.ctx.Done():
			b.cancelled = true
		case <-b.closeSignal: // Release unchanged late ready/close bytes to the retiring socket.
		case <-timer.C:
			interrupted = false
		}
		b.sample.finish(interrupted)
	})
	if b.cancelled {
		return 0, context.Canceled
	}
	return b.ReadWriteCloser.Read(p)
}
