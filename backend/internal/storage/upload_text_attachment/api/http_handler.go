package uploadtextattachmentapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	authorize "voice-platform/backend/internal/storage/authorize_text_attachment"
	finalize "voice-platform/backend/internal/storage/finalize_staged_text_attachment"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
	uploadrequest "voice-platform/backend/internal/storage/upload_request"
	upload "voice-platform/backend/internal/storage/upload_text_attachment"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

const maxRequestBytes int64 = writeupload.MaxBytes + 1_000_000
const uploadMaximumDuration = 15 * time.Minute
const uploadIdleDuration = time.Minute

type Uploader interface {
	Upload(context.Context, upload.Input) (upload.Result, error)
}

type FailureRecorder interface {
	UploadFailed(reason string)
}

func NewHandler(uploader Uploader, failures FailureRecorder) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			failures.UploadFailed("internal")
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить вложение")
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
			if isTooLarge(err) {
				failures.UploadFailed("too_large")
			} else {
				failures.UploadFailed("invalid_multipart")
			}
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Ожидался файл вложения")
			return
		}
		part, err := reader.NextPart()
		if err != nil || part.FormName() != "file" || part.FileName() == "" {
			if uploadrequest.TimedOut(request.Context()) {
				failures.UploadFailed("timeout")
				writeError(writer, request, http.StatusRequestTimeout, "UPLOAD_TIMEOUT", "Передача вложения превысила допустимое время")
				return
			}
			if isTooLarge(err) {
				failures.UploadFailed("too_large")
			} else {
				failures.UploadFailed("invalid_multipart")
			}
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Ожидался файл вложения")
			return
		}
		defer part.Close()
		result, err := uploader.Upload(request.Context(), upload.Input{ActorID: principal.AccountID, ChannelID: request.PathValue("channelID"), OriginalName: part.FileName(), Source: part})
		if uploadrequest.TimedOut(request.Context()) {
			failures.UploadFailed("timeout")
			writeError(writer, request, http.StatusRequestTimeout, "UPLOAD_TIMEOUT", "Передача вложения превысила допустимое время")
			return
		}
		if isTooLarge(err) {
			failures.UploadFailed("too_large")
			writeError(writer, request, http.StatusRequestEntityTooLarge, "ATTACHMENT_TOO_LARGE", "Файл превышает допустимый размер")
			return
		}
		if errors.Is(err, reserve.ErrInsufficientStorage) {
			failures.UploadFailed("insufficient_storage")
			writeError(writer, request, http.StatusInsufficientStorage, "INSUFFICIENT_STORAGE", "Недостаточно свободного места для вложения")
			return
		}
		if errors.Is(err, authorize.ErrTargetUnavailable) || errors.Is(err, finalize.ErrTargetUnavailable) {
			failures.UploadFailed("target_unavailable")
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Текстовый канал недоступен")
			return
		}
		if err != nil {
			failures.UploadFailed("internal")
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить вложение")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		writer.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(writer).Encode(map[string]any{"id": result.ID, "original_name": result.OriginalName, "byte_size": result.SizeBytes})
	})
}

func isTooLarge(err error) bool {
	var maxBytesError *http.MaxBytesError
	return errors.Is(err, writeupload.ErrTooLarge) || errors.Is(err, io.ErrUnexpectedEOF) || errors.As(err, &maxBytesError)
}
