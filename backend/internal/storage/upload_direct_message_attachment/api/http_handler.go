package uploaddirectmessageattachmentapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
	authorize "voice-platform/backend/internal/storage/authorize_direct_message_attachment"
	finalize "voice-platform/backend/internal/storage/finalize_staged_direct_message_attachment"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
	upload "voice-platform/backend/internal/storage/upload_direct_message_attachment"
	uploadrequest "voice-platform/backend/internal/storage/upload_request"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

const maxRequestBytes int64 = writeupload.MaxBytes + 1_000_000
const uploadMaximumDuration = 15 * time.Minute
const uploadIdleDuration = time.Minute

type Uploader interface {
	Upload(context.Context, upload.Input) (upload.Result, error)
}
type FailureRecorder interface{ UploadFailed(string) }

func NewHandler(uploader Uploader, failures FailureRecorder) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			failures.UploadFailed("internal")
			writeError(writer, request, 500, "INTERNAL", "Не удалось загрузить вложение")
			return
		}
		request, cleanup, err := uploadrequest.WithLimits(writer, request, uploadMaximumDuration, uploadIdleDuration)
		if err != nil {
			failures.UploadFailed("internal")
			writer.Header().Set("Connection", "close")
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить вложение")
			return
		}
		defer cleanup()
		defer request.Body.Close()
		request.Body = http.MaxBytesReader(writer, request.Body, maxRequestBytes)
		reader, err := request.MultipartReader()
		if err != nil {
			if uploadrequest.TimedOut(request.Context()) {
				failures.UploadFailed("timeout")
				writeError(writer, request, http.StatusRequestTimeout, "UPLOAD_TIMEOUT", "Передача вложения превысила допустимое время")
				return
			}
			failures.UploadFailed("invalid_multipart")
			writeError(writer, request, 400, "VALIDATION_FAILED", "Ожидался файл вложения")
			return
		}
		part, err := reader.NextPart()
		if err != nil || part.FormName() != "file" || part.FileName() == "" {
			if uploadrequest.TimedOut(request.Context()) {
				failures.UploadFailed("timeout")
				writeError(writer, request, http.StatusRequestTimeout, "UPLOAD_TIMEOUT", "Передача вложения превысила допустимое время")
				return
			}
			failures.UploadFailed("invalid_multipart")
			writeError(writer, request, 400, "VALIDATION_FAILED", "Ожидался файл вложения")
			return
		}
		defer part.Close()
		result, err := uploader.Upload(request.Context(), upload.Input{ActorID: principal.AccountID, DirectMessageID: request.PathValue("directMessageID"), OriginalName: part.FileName(), Source: part})
		switch {
		case uploadrequest.TimedOut(request.Context()):
			failures.UploadFailed("timeout")
			writeError(writer, request, http.StatusRequestTimeout, "UPLOAD_TIMEOUT", "Передача вложения превысила допустимое время")
		case tooLarge(err):
			failures.UploadFailed("too_large")
			writeError(writer, request, 413, "ATTACHMENT_TOO_LARGE", "Файл превышает допустимый размер")
		case errors.Is(err, reserve.ErrInsufficientStorage):
			failures.UploadFailed("insufficient_storage")
			writeError(writer, request, 507, "INSUFFICIENT_STORAGE", "Недостаточно свободного места для вложения")
		case errors.Is(err, authorize.ErrTargetUnavailable), errors.Is(err, authorize.ErrInvalidInput), errors.Is(err, finalize.ErrTargetUnavailable):
			failures.UploadFailed("target_unavailable")
			writeError(writer, request, 404, "NOT_FOUND", "Личный диалог недоступен")
		case err != nil:
			failures.UploadFailed("internal")
			writeError(writer, request, 500, "INTERNAL", "Не удалось загрузить вложение")
		default:
			writer.Header().Set("Content-Type", "application/json; charset=utf-8")
			writer.WriteHeader(http.StatusCreated)
			_ = json.NewEncoder(writer).Encode(map[string]any{"id": result.ID, "original_name": result.OriginalName, "byte_size": result.SizeBytes})
		}
	})
}

func tooLarge(err error) bool {
	var max *http.MaxBytesError
	return errors.Is(err, writeupload.ErrTooLarge) || errors.Is(err, io.ErrUnexpectedEOF) || errors.As(err, &max)
}
func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
