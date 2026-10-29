package screenpreviewapi

import (
	"context"
	"net/http"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

type Operations interface {
	Begin(context.Context, screenpreview.Principal, string) (screenpreview.Generation, error)
	Read(context.Context, screenpreview.Principal, string, string, uint64) (screenpreview.Preview, error)
	Invalidate(context.Context, screenpreview.Principal, string, string) error
}
type Handler struct {
	operations Operations
	slots      chan struct{}
}

func RegisterRoutes(mux *http.ServeMux, sessions sessionapi.Authenticator, operations Operations) {
	handler := &Handler{operations: operations, slots: make(chan struct{}, 32)}
	protect := func(next http.Handler) http.Handler {
		return privateHeaders(sessionapi.Require(sessions)(handler.limit(next)))
	}
	mux.Handle("POST /api/v1/voice/leases/{leaseID}/screen-previews/v1", protect(http.HandlerFunc(handler.begin)))
	generation := "/api/v1/voice/leases/{leaseID}/screen-previews/v1/{generationID}"
	mux.Handle("PUT "+generation, protect(http.HandlerFunc(handler.upload)))
	mux.Handle("DELETE "+generation, protect(http.HandlerFunc(handler.invalidate)))
	mux.Handle("GET /api/v1/voice/screen-previews/v1/leases/{leaseID}/{generationID}", protect(http.HandlerFunc(handler.read)))
}

func (handler *Handler) limit(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		select {
		case handler.slots <- struct{}{}:
			defer func() { <-handler.slots }()
			next.ServeHTTP(writer, request)
		default:
			writeFailure(writer, request, screenpreview.ErrRateLimited)
		}
	})
}

func privateHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Cache-Control", "private, no-store, max-age=0")
		writer.Header().Set("Pragma", "no-cache")
		writer.Header().Set("Expires", "0")
		writer.Header().Set("X-Content-Type-Options", "nosniff")
		writer.Header().Set("Vary", "Cookie")
		next.ServeHTTP(writer, request)
	})
}
