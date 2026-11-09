// Package admitpublicconnection bounds anonymous connections before upgrade.
package admitpublicconnection

import (
	"errors"
	"net"
	"sync"
)

var ErrInvalidConfig = errors.New("invalid public realtime connection quota")

// SourceLimit must accommodate at least twenty clients behind one NAT.
type Config struct{ GlobalLimit, SourceLimit int }

type Limiter struct {
	mu                               sync.Mutex
	globalLimit, sourceLimit, active int
	sources                          map[string]int
}

func New(config Config) (*Limiter, error) {
	if config.SourceLimit < 20 || config.GlobalLimit < config.SourceLimit {
		return nil, ErrInvalidConfig
	}
	return &Limiter{globalLimit: config.GlobalLimit, sourceLimit: config.SourceLimit,
		sources: make(map[string]int)}, nil
}

// TryAcquire accepts only the trusted source resolved by the caller's proxy policy.
// The returned release is safe to call more than once, including concurrently.
func (limiter *Limiter) TryAcquire(source string) (func(), bool) {
	ip := net.ParseIP(source)
	if ip == nil {
		return func() {}, false
	}
	key := ip.String()
	limiter.mu.Lock()
	if limiter.active >= limiter.globalLimit || limiter.sources[key] >= limiter.sourceLimit {
		limiter.mu.Unlock()
		return func() {}, false
	}
	limiter.active++
	limiter.sources[key]++
	limiter.mu.Unlock()
	var once sync.Once
	return func() { once.Do(func() { limiter.release(key) }) }, true
}

func (limiter *Limiter) release(key string) {
	limiter.mu.Lock()
	defer limiter.mu.Unlock()
	limiter.active--
	if limiter.sources[key] == 1 {
		delete(limiter.sources, key)
	} else {
		limiter.sources[key]--
	}
}
