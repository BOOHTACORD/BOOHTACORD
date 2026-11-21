package main

import (
	"crypto/subtle"
	"encoding/json"
	"net/http"
	"strings"
	"sync"
	"time"
)

type sample struct {
	mu             sync.Mutex
	Mode           string `json:"mode"`
	Seen           int    `json:"seen"`
	Cancelled      bool   `json:"cancelled"`
	Elapsed        int64  `json:"elapsed_ms"`
	ResponseStatus int    `json:"response_status"`
	start          time.Time
}

func (v *sample) response(status int) { v.mu.Lock(); v.ResponseStatus = status; v.mu.Unlock() }

func (v *sample) finish(cancelled bool) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.Cancelled = cancelled
	v.Elapsed = time.Since(v.start).Milliseconds()
}

type state struct {
	mu             sync.Mutex
	token, pending string
	current        *sample
}

func newState(token string) *state { return &state{token: token, current: &sample{}} }
func (s *state) arm(mode string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.pending = mode
	s.current = &sample{Mode: mode}
}
func (s *state) take(path string) string {
	_, mode := s.consume(path)
	return mode
}
func (s *state) consume(path string) (*sample, string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	session := strings.HasPrefix(s.pending, "session")
	public := strings.HasPrefix(s.pending, "public-")
	if public && path != "/api/v1/public/realtime" {
		return nil, ""
	}
	if s.pending == "" || (session && path != "/api/v1/auth/session") ||
		(!session && !public && path != "/api/v1/realtime") {
		return nil, ""
	}
	mode := s.pending
	s.pending = ""
	s.current.mu.Lock()
	s.current.Seen = 1
	s.current.start = time.Now()
	s.current.mu.Unlock()
	return s.current, mode
}
func (s *state) control(w http.ResponseWriter, r *http.Request) {
	if subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), []byte("Bearer "+s.token)) != 1 {
		http.Error(w, "Forbidden", 403)
		return
	}
	if r.Method == "POST" {
		var value struct {
			Mode string `json:"mode"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1024))
		decoder.DisallowUnknownFields()
		modes := map[string]bool{"upgrade-error": true, "upgrade-stall": true, "ready-stall": true,
			"split-budget": true, "session-stall": true, "session-late401": true}
		for _, name := range []string{"upgrade-error", "upgrade-stall", "ready-stall", "split-budget"} {
			modes["public-"+name] = true
		}
		if decoder.Decode(&value) != nil || !modes[value.Mode] {
			http.Error(w, "Invalid mode", 400)
			return
		}
		s.arm(value.Mode)
	} else if r.Method != "GET" {
		http.Error(w, "Method", 405)
		return
	}
	s.mu.Lock()
	value := s.current
	s.mu.Unlock()
	value.mu.Lock()
	defer value.mu.Unlock()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(value)
}
