// Package centralexport owns a bounded, disposable external delivery queue.
package centralexport

import (
	"context"
	"github.com/google/uuid"
	"net/http"
	"sync"
	"time"
	identity "voice-platform/backend/internal/observability/installation"
)

type Load func(context.Context) (identity.Identity, error)
type Save func(context.Context, identity.Identity) error
type Snapshot struct {
	InstallationID string     `json:"installation_id"`
	Mode           string     `json:"mode"`
	State          string     `json:"state"`
	Registered     bool       `json:"registered"`
	LastAccepted   *time.Time `json:"last_accepted_at"`
	Queued         int        `json:"queued"`
	Dropped        uint64     `json:"dropped"`
}
type item struct {
	kind       string
	body       []byte
	at         time.Time
	generation uint64
}
type Runtime struct {
	RecordAcceptance func(context.Context, identity.Identity, time.Time) error
	configureMu      sync.Mutex
	mu               sync.Mutex
	identity         identity.Identity
	instance         string
	generation       uint64
	queue            []item
	bytes            int
	wake             chan struct{}
	load             Load
	save             Save
	client           *http.Client
	cancel           context.CancelFunc
	active           context.CancelFunc
	done             chan struct{}
	last             *time.Time
	state            string
	dropped          uint64
}

// An explicitly supplied client allows trusted transports with private PKI.
// Product composition uses the default HTTPS-only public-address transport.
func New(i identity.Identity, load Load, save Save, clients ...*http.Client) *Runtime {
	client := secureClient()
	if len(clients) > 0 && clients[0] != nil {
		client = clients[0]
	}
	return &Runtime{identity: i, instance: uuid.NewString(), wake: make(chan struct{}, 1), load: load, save: save, client: client, state: "never_connected", last: i.LastAccepted}
}
func (r *Runtime) Identity() identity.Identity { r.mu.Lock(); defer r.mu.Unlock(); return r.identity }
func (r *Runtime) Instance() string            { return r.instance }
func (r *Runtime) Snapshot() Snapshot {
	r.mu.Lock()
	defer r.mu.Unlock()
	i := r.identity
	s := r.state
	if i.Valid() != nil {
		s = "unavailable"
	} else if i.Mode != "central" {
		s = "disabled"
	} else if r.last != nil && time.Since(*r.last) > time.Minute {
		s = "stale"
	}
	mode := i.Mode
	if mode != "central" {
		mode = "local_only"
	}
	return Snapshot{i.ID, mode, s, i.Enrolled, r.last, len(r.queue), r.dropped}
}
func (r *Runtime) replace(i identity.Identity) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if i.ID != r.identity.ID {
		r.last = i.LastAccepted
		r.state = "never_connected"
	}
	if i.ID != r.identity.ID || i.Credential != r.identity.Credential || i.Mode != r.identity.Mode || i.Endpoint != r.identity.Endpoint {
		r.generation++
		r.queue = nil
		r.bytes = 0
		if r.active != nil {
			r.active()
			r.active = nil
		}
	}
	r.identity = i
	if i.LastAccepted != nil && (r.last == nil || i.LastAccepted.After(*r.last)) {
		r.last = i.LastAccepted
	}
}
func (r *Runtime) Enqueue(kind string, body []byte) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	i := r.identity
	if i.Valid() != nil || i.Mode != "central" || i.Credential == "" {
		return false
	}
	if len(body) > 2*1024*1024 || len(r.queue) >= 32 || r.bytes+len(body) > 16*1024*1024 {
		r.dropped++
		return false
	}
	r.queue = append(r.queue, item{kind, body, time.Now(), r.generation})
	r.bytes += len(body)
	select {
	case r.wake <- struct{}{}:
	default:
	}
	return true
}
func (r *Runtime) Disable(ctx context.Context) error {
	r.configureMu.Lock()
	defer r.configureMu.Unlock()
	prior := r.Identity()
	i := prior
	i.Mode = "local_only"
	i.Credential = ""
	if r.save != nil {
		if err := r.save(ctx, i); err != nil {
			return err
		}
	}
	r.replace(i)
	if prior.Credential != "" {
		r.notifyDisabled(ctx, prior)
	}
	return nil
}
func (r *Runtime) Start(ctx context.Context) func(context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	r.mu.Lock()
	r.cancel = cancel
	r.done = make(chan struct{})
	r.mu.Unlock()
	go r.run(ctx)
	return func(stop context.Context) error {
		cancel()
		select {
		case <-r.done:
			return nil
		case <-stop.Done():
			return stop.Err()
		}
	}
}
func (r *Runtime) run(ctx context.Context) {
	defer close(r.done)
	tick := time.NewTicker(time.Second)
	defer tick.Stop()
	failures := 0
	var circuit time.Time
	for {
		select {
		case <-ctx.Done():
			r.replace(identity.Identity{})
			return
		case <-tick.C:
		case <-r.wake:
		}
		if r.load != nil {
			r.configureMu.Lock()
			bounded, cancel := context.WithTimeout(ctx, 2*time.Second)
			i, err := r.load(bounded)
			cancel()
			if err != nil {
				r.replace(identity.Identity{})
				r.configureMu.Unlock()
				continue
			}
			r.replace(i)
			r.configureMu.Unlock()
		}
		if time.Now().Before(circuit) {
			continue
		}
		r.mu.Lock()
		if len(r.queue) == 0 {
			r.mu.Unlock()
			continue
		}
		next := r.queue[0]
		r.queue = r.queue[1:]
		r.bytes -= len(next.body)
		i, gen := r.identity, r.generation
		send, cancel := context.WithCancel(ctx)
		r.active = cancel
		r.mu.Unlock()
		if next.generation != gen || time.Since(next.at) > time.Minute {
			cancel()
			continue
		}
		status := r.deliver(send, next, i)
		if status == 200 && r.RecordAcceptance != nil {
			bounded, saveCancel := context.WithTimeout(send, 2*time.Second)
			_ = r.RecordAcceptance(bounded, i, time.Now())
			saveCancel()
		}
		cancel()
		r.mu.Lock()
		r.active = nil
		if gen == r.generation {
			if status == 200 {
				at := time.Now()
				r.last = &at
				r.state = "exporting"
				failures = 0
			} else {
				r.dropped++
				r.state = "degraded"
				if status == 401 {
					r.state = "revoked"
				}
				failures++
				if failures >= 5 {
					circuit = time.Now().Add(30 * time.Second)
					failures = 0
				}
			}
		}
		more := len(r.queue) > 0
		r.mu.Unlock()
		if more {
			select {
			case r.wake <- struct{}{}:
			default:
			}
		}
	}
}

type contextKey struct{}

func Context(ctx context.Context, r *Runtime) context.Context {
	return context.WithValue(ctx, contextKey{}, r)
}
func From(ctx context.Context) *Runtime { v, _ := ctx.Value(contextKey{}).(*Runtime); return v }
