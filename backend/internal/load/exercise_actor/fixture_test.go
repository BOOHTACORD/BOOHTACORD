package exercise_actor

import (
	"encoding/json"
	"github.com/coder/websocket"
	"github.com/google/uuid"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"voice-platform/backend/internal/load/validate_target"
)

type fixture struct {
	manifest                                     validate_target.Manifest
	server                                       *httptest.Server
	mu                                           sync.Mutex
	sockets                                      map[*websocket.Conn]bool
	events                                       []map[string]any
	wrongOwner, corrupt, forceResync, enforceNAT bool
	natAttempts                                  int
	natAccounts                                  map[string]int
	attachment                                   []byte
}

func newFixture(t *testing.T) *fixture {
	f := &fixture{sockets: map[*websocket.Conn]bool{}}
	f.server = httptest.NewTLSServer(http.HandlerFunc(f.serve))
	f.manifest = validate_target.Manifest{Origin: f.server.URL, Guard: "http://127.0.0.1:4890", Nonce: strings.Repeat("x", 32), Dataset: "qa", Owner: "qa-client-0123456789abcdef", Commit: strings.Repeat("a", 40), Text: uuid.NewString(), PrivateDM: uuid.NewString(), Voice: []string{uuid.NewString()}, Accounts: []validate_target.Account{{Login: "qa_load_000", Password: "secret", ID: uuid.NewString()}}, UploadBytes: 1024, MaxRequests: 1000, MaxSeconds: 60}
	return f
}
func (f *fixture) close() {
	f.mu.Lock()
	for socket := range f.sockets {
		socket.CloseNow()
	}
	f.mu.Unlock()
	f.server.Close()
}
func (f *fixture) serve(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/api/v1")
	if r.Method != "GET" && r.Header.Get("Origin") != f.manifest.Origin {
		w.WriteHeader(403)
		return
	}
	if path == "/auth/login" {
		if f.enforceNAT {
			f.natAttempts++
			if f.natAttempts > 10 {
				w.Header().Set("Retry-After", "300")
				w.WriteHeader(429)
				json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": "RATE_LIMITED"}})
				return
			}
			var body struct {
				Login string `json:"login"`
			}
			if json.NewDecoder(r.Body).Decode(&body) != nil {
				w.WriteHeader(400)
				return
			}
			if f.natAccounts == nil {
				f.natAccounts = map[string]int{}
			}
			f.natAccounts[body.Login]++
			if f.natAccounts[body.Login] > 8 {
				w.Header().Set("Retry-After", "30")
				w.WriteHeader(429)
				json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": "RATE_LIMITED"}})
				return
			}
			if body.Login != f.manifest.Accounts[0].Login {
				w.WriteHeader(401)
				json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": "UNAUTHENTICATED"}})
				return
			}

		}
		http.SetCookie(w, &http.Cookie{Name: "vp_session", Value: "synthetic", Path: "/", Secure: true})
		w.WriteHeader(204)
		return
	}
	cookie, err := r.Cookie("vp_session")
	if err != nil || cookie.Value != "synthetic" {
		w.WriteHeader(401)
		return
	}
	if path == "/auth/logout" {
		http.SetCookie(w, &http.Cookie{Name: "vp_session", Path: "/", MaxAge: -1})
		w.WriteHeader(204)
		return
	}
	if path == "/auth/session" {
		id := f.manifest.Accounts[0].ID
		if f.wrongOwner {
			id = uuid.NewString()
		}
		json.NewEncoder(w).Encode(map[string]any{"authenticated": true, "account_id": id, "role": "MEMBER"})
		return
	}
	if path == "/realtime" {
		f.ws(w, r)
		return
	}
	if path == "/admin/audit" {
		w.WriteHeader(403)
		return
	}
	if strings.HasPrefix(path, "/direct-messages/") {
		if path == "/direct-messages/"+f.manifest.PrivateDM+"/messages" {
			w.Write([]byte(`{"messages":[]}`))
		} else {
			w.WriteHeader(404)
		}
		return
	}
	if strings.Contains(path, "/attachments") {
		f.upload(w, r)
		return
	}
	if strings.HasSuffix(path, "/messages") && r.Method == "POST" {
		f.message(w, r)
		return
	}
	if strings.HasSuffix(path, "/leases") {
		w.WriteHeader(201)
		json.NewEncoder(w).Encode(map[string]any{"id": uuid.NewString()})
		return
	}
	if r.Method == "DELETE" {
		w.WriteHeader(204)
		return
	}
	json.NewEncoder(w).Encode(map[string]any{"categories": []any{}, "messages": []any{}})
}
