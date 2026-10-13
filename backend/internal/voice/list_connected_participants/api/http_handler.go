package listconnectedparticipantsapi

import (
	"context"
	"encoding/json"
	"net/http"

	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
	listconnectedparticipants "voice-platform/backend/internal/voice/list_connected_participants"
)

type Lister interface {
	List(context.Context, string) (listconnectedparticipants.Result, error)
}

func NewHandler(lister Lister) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Cache-Control", "no-store")
		if request.Method != http.MethodGet {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL")
			return
		}
		snapshot, cancel := context.WithTimeout(request.Context(), authenticatesession.SessionLookupTimeout)
		defer cancel()
		result, err := lister.List(snapshot, principal.AccountID)
		if err != nil && listconnectedparticipants.FailureStatus(err) == http.StatusServiceUnavailable {
			writer.Header().Set("Retry-After", "1")
			writeError(writer, request, http.StatusServiceUnavailable, "VOICE_PRESENCE_UNAVAILABLE")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(result)
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code": code, "message": "Не удалось загрузить участников голосовых комнат", "request_id": requestid.From(request.Context()),
	}})
}
