package listdirectmessagesapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"
	support "voice-platform/backend/internal/support/contact"

	listdirectmessages "voice-platform/backend/internal/chat/list_direct_messages"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Lister interface {
	List(context.Context, listdirectmessages.Input) (listdirectmessages.Result, error)
}

type SupportResolver interface {
	Resolve(context.Context, string) (support.Contact, error)
}

func NewHandler(lister Lister, resolvers ...SupportResolver) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить личные диалоги")
			return
		}
		result, err := lister.List(request.Context(), listdirectmessages.Input{ActorID: principal.AccountID})
		if errors.Is(err, listdirectmessages.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный пользователь")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить личные диалоги")
			return
		}
		var contact *support.Contact
		if len(resolvers) > 0 && resolvers[0] != nil {
			value, err := resolvers[0].Resolve(request.Context(), principal.AccountID)
			if err != nil {
				value = support.Contact{State: "unavailable"}
			}
			contact = &value
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(response{DirectMessages: directMessages(result.DirectMessages), SupportContact: contact})
	})
}

type response struct {
	SupportContact *support.Contact `json:"support_contact,omitempty"`
	DirectMessages []directMessage  `json:"direct_messages"`
}
type directMessage struct {
	ID                          string    `json:"id"`
	OtherParticipantID          string    `json:"other_participant_id"`
	OtherParticipantDisplayName string    `json:"other_participant_display_name"`
	CreatedAt                   time.Time `json:"created_at"`
	UnreadCount                 int64     `json:"unread_count"`
	MentionCount                int64     `json:"mention_count"`
	FirstUnreadMessageID        string    `json:"first_unread_message_id,omitempty"`
}

func directMessages(source []listdirectmessages.DirectMessage) []directMessage {
	result := make([]directMessage, 0, len(source))
	for _, value := range source {
		result = append(result, directMessage{ID: value.ID, OtherParticipantID: value.OtherParticipantID, OtherParticipantDisplayName: value.OtherParticipantDisplayName, CreatedAt: value.CreatedAt, UnreadCount: value.UnreadCount, MentionCount: value.MentionCount, FirstUnreadMessageID: value.FirstUnreadMessageID})
	}
	return result
}
func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
