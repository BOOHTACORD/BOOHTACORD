// Package centralgateway authenticates installations before assigning storage scope.
package centralgateway

import (
	"bytes"
	"context"
	"crypto/hmac"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
	projection "voice-platform/backend/internal/observability/central_projection"
	identity "voice-platform/backend/internal/observability/installation"
)

type Config struct {
	Registry                        Registry
	CredentialKey                   []byte
	ReadToken, TempoURL, MetricsURL string
	TempoQueryURL                   string
	Client                          *http.Client
}
type budget struct {
	at              time.Time
	requests, bytes int
}
type Gateway struct {
	config  Config
	mu      sync.Mutex
	budgets map[string]budget
	active  chan struct{}
	series  map[string]time.Time
}

func New(c Config) (*Gateway, error) {
	if c.TempoQueryURL == "" {
		c.TempoQueryURL = c.TempoURL
	}
	if c.Registry == nil || len(c.CredentialKey) < 32 || c.ReadToken == "" {
		return nil, ErrRegistry
	}
	for _, raw := range []string{c.TempoURL, c.TempoQueryURL, c.MetricsURL} {
		u, e := url.Parse(raw)
		if e != nil || u.Host == "" || u.User != nil || (u.Scheme != "http" && u.Scheme != "https") {
			return nil, ErrRegistry
		}
	}
	if c.Client == nil {
		transport := http.DefaultTransport.(*http.Transport).Clone()
		transport.Proxy = nil
		c.Client = &http.Client{Transport: transport, Timeout: 3 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	}
	return &Gateway{config: c, budgets: map[string]budget{}, active: make(chan struct{}, 32)}, nil
}
func (g *Gateway) allow(key string, size, limit int) bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	now := time.Now()
	b := g.budgets[key]
	if now.Sub(b.at) > time.Minute {
		b = budget{at: now}
	}
	if b.requests >= limit || b.bytes+size > 32*1024*1024 {
		return false
	}
	if len(g.budgets) >= 12000 {
		for k, v := range g.budgets {
			if now.Sub(v.at) > 2*time.Minute {
				delete(g.budgets, k)
			}
		}
		if len(g.budgets) >= 12000 {
			return false
		}
	}
	b.requests++
	b.bytes += size
	g.budgets[key] = b
	return true
}
func (g *Gateway) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/metrics" && r.Method == "GET" {
		g.metrics(w, r)
		return
	}
	if strings.HasPrefix(r.URL.Path, "/read/tempo/") {
		g.read(w, r)
		return
	}
	if r.Method != "POST" {
		w.WriteHeader(405)
		return
	}
	if r.URL.Path == "/v1/enroll" {
		g.enroll(w, r)
		return
	}
	if r.URL.Path != "/v1/traces" && r.URL.Path != "/v1/metrics" && r.URL.Path != "/v1/status" {
		w.WriteHeader(404)
		return
	}
	token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	id, _, ok := strings.Cut(token, ".")
	if !ok {
		w.WriteHeader(401)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 4*time.Second)
	defer cancel()
	record, err := g.config.Registry.Get(ctx, id)
	if err != nil || !record.Enabled || !hmac.Equal([]byte(token), []byte(credential(g.config.CredentialKey, record))) {
		w.WriteHeader(401)
		return
	}
	if r.URL.Path == "/v1/status" {
		if !g.allow("installation:"+id, 256, 120) {
			w.WriteHeader(429)
			return
		}
		var input struct {
			Mode string `json:"mode"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 256))
		decoder.DisallowUnknownFields()
		if decoder.Decode(&input) != nil || input.Mode != "disabled" {
			w.WriteHeader(400)
			return
		}
		store, ok := g.config.Registry.(interface {
			SetMode(context.Context, string, string) error
		})
		if !ok || store.SetMode(ctx, id, input.Mode) != nil {
			w.WriteHeader(503)
			return
		}
		w.WriteHeader(200)
		return
	}
	if record.Mode == "disabled" {
		w.WriteHeader(409)
		return
	}
	if r.Header.Get("Content-Encoding") != "" || !strings.HasPrefix(r.Header.Get("Content-Type"), "application/x-protobuf") {
		w.WriteHeader(415)
		return
	}
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, projection.MaxBytes))
	if err != nil {
		w.WriteHeader(413)
		return
	}
	if !g.allow("installation:"+id, len(raw), 120) {
		w.WriteHeader(429)
		return
	}
	select {
	case g.active <- struct{}{}:
		defer func() { <-g.active }()
	default:
		w.WriteHeader(429)
		return
	}
	target := g.config.TempoURL
	var clean []byte
	i := identity.Identity{ID: id}
	if r.URL.Path == "/v1/traces" {
		clean, err = projection.Traces(raw, i)
	} else {
		target = g.config.MetricsURL
		clean, err = projection.Metrics(raw, i)
	}
	if err != nil {
		w.WriteHeader(400)
		return
	}
	if r.URL.Path == "/v1/metrics" && !g.cardinality(id, clean) {
		w.WriteHeader(429)
		return
	}
	req, err := http.NewRequestWithContext(ctx, "POST", strings.TrimRight(target, "/")+r.URL.Path, bytes.NewReader(clean))
	if err != nil {
		w.WriteHeader(503)
		return
	}
	req.Header.Set("Content-Type", "application/x-protobuf")
	if r.URL.Path == "/v1/traces" {
		req.Header.Set("X-Scope-OrgID", id)
	}
	resp, err := g.config.Client.Do(req)
	if err != nil {
		w.WriteHeader(503)
		return
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 65537))
	if err != nil || len(body) > 65536 || resp.StatusCode < 200 || resp.StatusCode >= 300 {
		w.WriteHeader(503)
		return
	}
	if !fullAcceptance(r.URL.Path, body) {
		w.WriteHeader(503)
		return
	}

	_ = g.config.Registry.Seen(ctx, id)
	w.Header().Set("Content-Type", "application/x-protobuf")
	w.WriteHeader(200)
}
func (g *Gateway) enroll(w http.ResponseWriter, r *http.Request) {
	host, _, _ := net.SplitHostPort(r.RemoteAddr)
	if !g.allow("enroll:global", 0, 60) || !g.allow("enroll:"+host, 0, 20) {
		w.WriteHeader(429)
		return
	}
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 8192))
	if err != nil {
		w.WriteHeader(413)
		return
	}
	var e Enrollment
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&e) != nil {
		w.WriteHeader(400)
		return
	}
	key, ok := verifyEnrollment(e, time.Now())
	if !ok {
		w.WriteHeader(400)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()
	record, err := g.config.Registry.Enroll(ctx, e.InstallationID, key, e.Nonce)
	if err != nil {
		w.WriteHeader(409)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	jsonResponse(w, EnrollmentResponse{credential(g.config.CredentialKey, record), record.ID, 1})
}
