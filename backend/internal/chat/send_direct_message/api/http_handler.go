package senddirectmessageapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	senddirectmessage "voice-platform/backend/internal/chat/send_direct_message"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Sender interface {
	Send(context.Context, senddirectmessage.Input) (senddirectmessage.Result, error)
}

type PublicationGuard interface {
	ProductPair(context.Context, string, string) (bool, error)
}

func NewHandler(sender Sender, guards ...PublicationGuard) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось отправить личное сообщение")
			return
		}
		var body struct {
			ClientMessageID string   `json:"client_message_id"`
			ReplyToID       string   `json:"reply_to_id"`
			Body            string   `json:"body"`
			AttachmentIDs   []string `json:"attachment_ids"`
			MentionUserIDs  []string `json:"mention_user_ids"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 40<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные личного сообщения")
			return
		}
		if request.Header.Get("X-Boohtacord-Support-Publication") != "v1" && len(guards) > 0 {
			product, err := guards[0].ProductPair(request.Context(), principal.AccountID, request.PathValue("directMessageID"))
			if err != nil {
				writeError(writer, request, 500, "INTERNAL", "Не удалось отправить личное сообщение")
				return
			}
			if product {
				writeError(writer, request, 409, "SUPPORT_CLIENT_UPDATE_REQUIRED", "Обновите приложение, чтобы отправлять сообщения в публичную поддержку.")
				return
			}
		}
		result, err := sender.Send(request.Context(), senddirectmessage.Input{ActorID: principal.AccountID, DirectMessageID: request.PathValue("directMessageID"), ClientMessageID: body.ClientMessageID, ReplyToID: body.ReplyToID, Body: body.Body, AttachmentIDs: body.AttachmentIDs, MentionUserIDs: body.MentionUserIDs})
		if errors.Is(err, senddirectmessage.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные личного сообщения")
			return
		}
		if errors.Is(err, senddirectmessage.ErrDirectMessageUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Личный диалог недоступен")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось отправить личное сообщение")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		writer.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(writer).Encode(struct {
			ID              string    `json:"id"`
			DirectMessageID string    `json:"direct_message_id"`
			AuthorID        string    `json:"author_id"`
			ClientMessageID string    `json:"client_message_id"`
			Body            string    `json:"body"`
			ReplyToID       string    `json:"reply_to_id,omitempty"`
			Revision        int       `json:"revision"`
			CreatedAt       time.Time `json:"created_at"`
			MentionUserIDs  []string  `json:"mention_user_ids"`
		}{ID: result.ID, DirectMessageID: result.DirectMessageID, AuthorID: result.AuthorID, ClientMessageID: result.ClientMessageID, Body: result.Body, ReplyToID: result.ReplyToID, Revision: result.Revision, CreatedAt: result.CreatedAt, MentionUserIDs: nonNilMentions(result.MentionUserIDs)})
	})
}

func nonNilMentions(ids []string) []string {
	if ids == nil {
		return []string{}
	}
	return ids
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
