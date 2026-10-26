package centralgateway

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"encoding/json"
	collector "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	common "go.opentelemetry.io/proto/otlp/common/v1"
	resource "go.opentelemetry.io/proto/otlp/resource/v1"
	spans "go.opentelemetry.io/proto/otlp/trace/v1"
	"google.golang.org/protobuf/proto"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
	projection "voice-platform/backend/internal/observability/central_projection"
	identity "voice-platform/backend/internal/observability/installation"
)

type memoryRegistry struct {
	mu     sync.Mutex
	rows   map[string]Record
	nonces map[string]bool
}

func (m *memoryRegistry) Enroll(_ context.Context, id string, key []byte, nonce string) (Record, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	r, ok := m.rows[id]
	if ok && (!bytes.Equal(r.PublicKey, key) || !r.Enabled) {
		return Record{}, ErrRegistry
	}
	if m.nonces[id+nonce] {
		return Record{}, ErrRegistry
	}
	m.nonces[id+nonce] = true
	if !ok {
		r = Record{ID: id, PublicKey: key, Enabled: true, Epoch: 1}
		m.rows[id] = r
	}
	return r, nil
}
func (m *memoryRegistry) Get(_ context.Context, id string) (Record, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	r, ok := m.rows[id]
	if !ok {
		return r, ErrRegistry
	}
	return r, nil
}
func (m *memoryRegistry) Seen(context.Context, string) error { return nil }
func TestEnrollmentAndUntrustedTenantAreIsolated(t *testing.T) {
	a, _ := identity.New()
	b, _ := identity.New()
	var tenants []string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tenants = append(tenants, r.Header.Get("X-Scope-OrgID"))
		w.WriteHeader(200)
	}))
	defer upstream.Close()
	store := &memoryRegistry{rows: map[string]Record{}, nonces: map[string]bool{}}
	gateway, err := New(Config{Registry: store, CredentialKey: bytes.Repeat([]byte{1}, 32), ReadToken: "owner-only", TempoURL: upstream.URL, MetricsURL: upstream.URL})
	if err != nil {
		t.Fatal(err)
	}
	enroll := func(i identity.Identity) string {
		req := NewEnrollment(i, time.Now())
		body, _ := json.Marshal(req)
		w := httptest.NewRecorder()
		gateway.ServeHTTP(w, httptest.NewRequest("POST", "/v1/enroll", bytes.NewReader(body)))
		if w.Code != 200 {
			t.Fatalf("enroll status %d", w.Code)
		}
		var response EnrollmentResponse
		json.Unmarshal(w.Body.Bytes(), &response)
		return response.Credential
	}
	tokenA := enroll(a)
	tokenB := enroll(b)
	attack := NewEnrollment(b, time.Now())
	attack.InstallationID = a.ID
	attack.Signature = SignEnrollment(attack, b.PrivateKey())
	raw, _ := json.Marshal(attack)
	w := httptest.NewRecorder()
	gateway.ServeHTTP(w, httptest.NewRequest("POST", "/v1/enroll", bytes.NewReader(raw)))
	if w.Code == 200 {
		t.Fatal("installation stolen by different key")
	}
	_ = ed25519.PublicKeySize
	send := func(token string, i identity.Identity) int {
		now := uint64(time.Now().UnixNano())
		batch := &collector.ExportTraceServiceRequest{ResourceSpans: []*spans.ResourceSpans{{Resource: &resource.Resource{Attributes: []*common.KeyValue{projection.String("service.name", "boohtacord-api"), projection.String("boohtacord.installation.id", i.ID)}}, ScopeSpans: []*spans.ScopeSpans{{Spans: []*spans.Span{{Name: "api.request", TraceId: bytes.Repeat([]byte{1}, 16), SpanId: bytes.Repeat([]byte{2}, 8), StartTimeUnixNano: now - 1000, EndTimeUnixNano: now}}}}}}}
		raw, _ := proto.Marshal(batch)
		r := httptest.NewRequest("POST", "/v1/traces", bytes.NewReader(raw))
		r.Header.Set("Authorization", "Bearer "+token)
		r.Header.Set("Content-Type", "application/x-protobuf")
		r.Header.Set("X-Scope-OrgID", b.ID)
		w := httptest.NewRecorder()
		gateway.ServeHTTP(w, r)
		return w.Code
	}
	if send(tokenA, b) < 400 {
		t.Fatal("foreign body accepted")
	}
	if send(tokenA, a) != 200 || send(tokenB, b) != 200 {
		t.Fatal("valid export rejected")
	}
	if len(tenants) != 2 || tenants[0] != a.ID || tenants[1] != b.ID {
		t.Fatal("tenant crossed or client header trusted")
	}
	store.mu.Lock()
	r := store.rows[a.ID]
	r.Enabled = false
	store.rows[a.ID] = r
	store.mu.Unlock()
	if send(tokenA, a) != 401 || send(tokenB, b) != 200 {
		t.Fatal("revoke scope failed")
	}
}
