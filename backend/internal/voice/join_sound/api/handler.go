package joinsoundapi

import (
	"context"
	"io"
	"net/http"
	session "voice-platform/backend/internal/identity/authenticate_session/api"
	s "voice-platform/backend/internal/voice/join_sound"
)

type Service interface {
	Upload(context.Context, s.Actor, []byte) (s.Sound, error)
	Download(context.Context, s.Actor, string) (s.Sound, error)
	Current(context.Context, s.Actor) (s.Sound, error)
	Enable(context.Context, s.Actor, bool) (s.Sound, error)
	Delete(context.Context, s.Actor) error
}
type handler struct{ service Service }

func NewHandler(service Service) http.Handler { return handler{service} }
func (h handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	p, ok := session.PrincipalFrom(r.Context())
	if !ok {
		reply(w, 401, nil)
		return
	}
	actor := s.Actor{Account: p.AccountID, SessionDigest: p.SessionDigest}
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	if r.Header.Get("X-Voice-Sound-Account") != actor.Account {
		reply(w, 409, nil)
		return
	}
	switch r.Method {
	case "GET":
		value, err := h.service.Current(r.Context(), actor)
		if err != nil {
			failure(w, err)
			return
		}
		reply(w, 200, value)
	case "POST":
		raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, s.MaxInput))
		if err != nil {
			reply(w, 413, nil)
			return
		}
		value, err := h.service.Upload(r.Context(), actor, raw)
		if err != nil {
			failure(w, err)
			return
		}
		reply(w, 201, value)
	case "PATCH":
		enabled, err := decodeEnabled(w, r)
		if err != nil {
			reply(w, 400, nil)
			return
		}
		value, err := h.service.Enable(r.Context(), actor, enabled)
		if err != nil {
			failure(w, err)
			return
		}
		reply(w, 200, value)
	case "DELETE":
		if err := h.service.Delete(r.Context(), actor); err != nil {
			failure(w, err)
			return
		}
		w.WriteHeader(204)
	default:
		reply(w, 405, nil)
	}
}
