package joinsounddownload

import (
	"context"
	"errors"
	"net/http"
	session "voice-platform/backend/internal/identity/authenticate_session/api"
	s "voice-platform/backend/internal/voice/join_sound"
)

type Service interface {
	Download(context.Context, s.Actor, string) (s.Sound, error)
}

func NewDownloadHandler(service Service) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		p, ok := session.PrincipalFrom(r.Context())
		if !ok {
			w.WriteHeader(401)
			return
		}
		if r.Method != "GET" {
			w.WriteHeader(405)
			return
		}
		value, err := service.Download(r.Context(), s.Actor{Account: p.AccountID, SessionDigest: p.SessionDigest}, r.PathValue("id"))
		if err != nil {
			if errors.Is(err, s.ErrNotFound) {
				w.WriteHeader(404)
			} else {
				w.WriteHeader(500)
			}
			return
		}
		w.Header().Set("Content-Type", "audio/mpeg")
		w.WriteHeader(200)
		_, _ = w.Write(value.Audio.Bytes)
	})
}
