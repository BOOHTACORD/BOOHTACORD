package sessionapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"go.opentelemetry.io/otel/trace"
	"voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	correlatesession "voice-platform/backend/internal/observability/correlate_session"
	"voice-platform/backend/internal/security/request_id"
)

type Authenticator interface {
	Authenticate(context.Context, string) (authenticatesession.Principal, error)
}

type principalKey struct{}

func Require(authenticator Authenticator) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
			cookie, err := request.Cookie(session.CookieName)
			if err != nil {
				writeUnauthenticated(writer, request)
				return
			}
			principal, err := authenticator.Authenticate(request.Context(), cookie.Value)
			if errors.Is(err, authenticatesession.ErrUnauthenticated) {
				writeUnauthenticated(writer, request)
				return
			}
			if err != nil {
				if errors.Is(err, context.DeadlineExceeded) && (request.URL.Path == "/api/v1/voice/participants" || request.URL.Path == "/api/v1/voice/rosters/events") {
					writer.Header().Set("Cache-Control", "no-store")
					writer.Header().Set("Retry-After", "1")
					writer.Header().Set("Content-Type", "application/json; charset=utf-8")
					writer.WriteHeader(http.StatusServiceUnavailable)
					_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
						"code": "VOICE_PRESENCE_UNAVAILABLE", "message": "Не удалось загрузить участников голосовых комнат", "request_id": requestid.From(request.Context()),
					}})
					return
				}
				writer.WriteHeader(http.StatusInternalServerError)
				return
			}
			next.ServeHTTP(writer, request.WithContext(authenticatedContext(writer, request, principal)))
		})
	}
}

func Optional(authenticator Authenticator) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
			cookie, err := request.Cookie(session.CookieName)
			if err != nil {
				next.ServeHTTP(writer, request)
				return
			}
			principal, err := authenticator.Authenticate(request.Context(), cookie.Value)
			if errors.Is(err, authenticatesession.ErrUnauthenticated) {
				next.ServeHTTP(writer, request)
				return
			}
			if err != nil {
				writer.WriteHeader(http.StatusInternalServerError)
				return
			}
			next.ServeHTTP(writer, request.WithContext(authenticatedContext(writer, request, principal)))
		})
	}
}

func PrincipalFrom(context context.Context) (authenticatesession.Principal, bool) {
	principal, ok := context.Value(principalKey{}).(authenticatesession.Principal)
	return principal, ok
}

func WithPrincipal(ctx context.Context, principal authenticatesession.Principal) context.Context {
	if span := trace.SpanFromContext(ctx); span.IsRecording() {
		span.SetAttributes(correlatesession.NamedAttributes(principal.AccountID, principal.SessionDigest, principal.DisplayName)...)
	}
	return context.WithValue(ctx, principalKey{}, principal)
}

func writeUnauthenticated(writer http.ResponseWriter, request *http.Request) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(http.StatusUnauthorized)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code":       "UNAUTHENTICATED",
		"message":    "Требуется вход",
		"request_id": requestid.From(request.Context()),
	}})
}
