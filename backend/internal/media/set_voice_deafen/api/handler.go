package setvoicedeafenapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"mime"
	"net/http"
	"strings"
	"sync"
	"time"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	setvoicedeafen "voice-platform/backend/internal/media/set_voice_deafen"
	"voice-platform/backend/internal/security/request_id"
)

type Operations interface {
	Apply(context.Context, setvoicedeafen.Principal, string, bool) error
}
type Handler struct {
	operations     Operations
	sessions       sessionapi.Authenticator
	expectedOrigin string
	limiter        *sessionLimiter
}

func RegisterRoutes(mux *http.ServeMux, sessions sessionapi.Authenticator, operations Operations, expectedOrigin string) {
	handler := Handler{operations: operations, sessions: sessions, expectedOrigin: expectedOrigin, limiter: newSessionLimiter(20, time.Minute, 10000)}
	mux.Handle("PUT /api/v1/voice/leases/{leaseID}/deafen/v1", handler.protect(http.HandlerFunc(handler.update)))
}
func (handler Handler) protect(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "private, no-store, max-age=0")
		w.Header().Set("Pragma", "no-cache")
		w.Header().Set("Expires", "0")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Vary", "Cookie")
		sessionapi.Require(handler.sessions)(next).ServeHTTP(w, r)
	})
}
func (handler Handler) update(w http.ResponseWriter, r *http.Request) {
	if handler.expectedOrigin == "" || r.Header.Get("Origin") != handler.expectedOrigin {
		writeError(w, r, http.StatusForbidden, "FORBIDDEN")
		return
	}
	mediaType, params, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if err != nil || !strings.EqualFold(mediaType, "application/json") || len(params) != 0 {
		writeError(w, r, http.StatusUnsupportedMediaType, "UNSUPPORTED_MEDIA_TYPE")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 128))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED")
		return
	}
	deafened, valid := decodeBody(body)
	if !valid {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED")
		return
	}
	principal, ok := sessionapi.PrincipalFrom(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHENTICATED")
		return
	}
	if !handler.limiter.Allow(principal.SessionDigest, time.Now()) {
		writeError(w, r, http.StatusTooManyRequests, "RATE_LIMITED")
		return
	}
	who := setvoicedeafen.Principal{AccountID: principal.AccountID, SessionDigest: principal.SessionDigest}
	if err := handler.operations.Apply(r.Context(), who, r.PathValue("leaseID"), deafened); err != nil {
		status, code := http.StatusInternalServerError, "INTERNAL"
		if errors.Is(err, setvoicedeafen.ErrDenied) {
			status, code = http.StatusNotFound, "LEASE_NOT_AVAILABLE"
		}
		if errors.Is(err, setvoicedeafen.ErrInvalid) {
			status, code = http.StatusBadRequest, "VALIDATION_FAILED"
		}
		if errors.Is(err, setvoicedeafen.ErrUnavailable) {
			status, code = http.StatusServiceUnavailable, "VOICE_DEAFEN_UNAVAILABLE"
		}
		writeError(w, r, status, code)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
func decodeBody(body []byte) (bool, bool) {
	decoder := json.NewDecoder(bytes.NewReader(body))
	token, err := decoder.Token()
	if err != nil || token != json.Delim('{') {
		return false, false
	}
	seen := false
	var deafened bool
	for decoder.More() {
		keyToken, err := decoder.Token()
		key, ok := keyToken.(string)
		if err != nil || !ok || key != "deafened" || seen {
			return false, false
		}
		seen = true
		if err = decoder.Decode(&deafened); err != nil {
			return false, false
		}
	}
	if _, err = decoder.Token(); err != nil || !seen {
		return false, false
	}
	var trailing any
	if err = decoder.Decode(&trailing); err != io.EOF {
		return false, false
	}
	return deafened, true
}
func writeError(w http.ResponseWriter, r *http.Request, status int, code string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": "Не удалось обновить состояние отключения звука", "request_id": requestid.From(r.Context())}})
}

type sessionLimit struct {
	start time.Time
	count int
}
type sessionLimiter struct {
	mu         sync.Mutex
	entries    map[[32]byte]sessionLimit
	limit      int
	window     time.Duration
	maxEntries int
}

func newSessionLimiter(limit int, window time.Duration, maxEntries int) *sessionLimiter {
	return &sessionLimiter{entries: make(map[[32]byte]sessionLimit), limit: limit, window: window, maxEntries: maxEntries}
}
func (l *sessionLimiter) Allow(key [32]byte, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	current, ok := l.entries[key]
	if !ok || now.Sub(current.start) >= l.window {
		if len(l.entries) >= l.maxEntries {
			for candidate, value := range l.entries {
				if now.Sub(value.start) >= l.window {
					delete(l.entries, candidate)
				}
			}
			if len(l.entries) >= l.maxEntries {
				return false
			}
		}
		l.entries[key] = sessionLimit{start: now, count: 1}
		return true
	}
	if current.count >= l.limit {
		return false
	}
	current.count++
	l.entries[key] = current
	return true
}
