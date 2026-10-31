package uploadtextattachmentapi

import (
	"bytes"
	"context"
	"errors"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	authorize "voice-platform/backend/internal/storage/authorize_text_attachment"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
	upload "voice-platform/backend/internal/storage/upload_text_attachment"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

func TestHandlerStreamsFileForCurrentPrincipalAndPathChannel(t *testing.T) {
	body, contentType := multipartBody(t, "file", "image.png", "bytes")
	uploader, failures := &fakeUploader{}, &fakeFailureRecorder{}
	request := httptest.NewRequest(http.MethodPost, "/api/v1/channels/channel-1/attachments", body)
	request.Header.Set("Content-Type", contentType)
	request.SetPathValue("channelID", "channel-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1"}))
	recorder := newDeadlineRecorder()
	NewHandler(uploader, failures).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusCreated || len(failures.reasons) != 0 || uploader.input.ActorID != "user-1" || uploader.input.ChannelID != "channel-1" || uploader.input.OriginalName != "image.png" || !strings.Contains(recorder.Body.String(), `"id":"attachment-1"`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, uploader.input, recorder.Body.String())
	}
}

func TestHandlerRejectsMissingFilePart(t *testing.T) {
	body, contentType := multipartBody(t, "note", "", "bytes")
	request := httptest.NewRequest(http.MethodPost, "/api/v1/channels/channel-1/attachments", body)
	request.Header.Set("Content-Type", contentType)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1"}))
	recorder, failures := newDeadlineRecorder(), &fakeFailureRecorder{}
	NewHandler(&fakeUploader{}, failures).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusBadRequest || !strings.Contains(recorder.Body.String(), `"VALIDATION_FAILED"`) || !equalReasons(failures.reasons, []string{"invalid_multipart"}) {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

func TestHandlerRecordsBoundedUploadFailureReasons(t *testing.T) {
	for _, test := range []struct {
		name   string
		err    error
		status int
		reason string
	}{
		{name: "too large", err: writeupload.ErrTooLarge, status: http.StatusRequestEntityTooLarge, reason: "too_large"},
		{name: "storage", err: reserve.ErrInsufficientStorage, status: http.StatusInsufficientStorage, reason: "insufficient_storage"},
		{name: "target", err: authorize.ErrTargetUnavailable, status: http.StatusNotFound, reason: "target_unavailable"},
		{name: "internal", err: errors.New("private-name.png"), status: http.StatusInternalServerError, reason: "internal"},
	} {
		t.Run(test.name, func(t *testing.T) {
			body, contentType := multipartBody(t, "file", "image.png", "bytes")
			request := httptest.NewRequest(http.MethodPost, "/api/v1/channels/channel-1/attachments", body)
			request.Header.Set("Content-Type", contentType)
			request.SetPathValue("channelID", "channel-1")
			request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1"}))
			recorder, failures := newDeadlineRecorder(), &fakeFailureRecorder{}
			NewHandler(&fakeUploader{err: test.err}, failures).ServeHTTP(recorder, request)
			if recorder.Code != test.status || !equalReasons(failures.reasons, []string{test.reason}) || strings.Contains(recorder.Body.String(), "private-name.png") {
				t.Fatalf("status = %d, reasons = %#v, body = %q", recorder.Code, failures.reasons, recorder.Body.String())
			}
		})
	}
}

type fakeUploader struct {
	err   error
	input upload.Input
}

func (uploader *fakeUploader) Upload(_ context.Context, input upload.Input) (upload.Result, error) {
	uploader.input = input
	return upload.Result{ID: "attachment-1", OriginalName: input.OriginalName, SizeBytes: 5}, uploader.err
}

type fakeFailureRecorder struct{ reasons []string }

func (recorder *fakeFailureRecorder) UploadFailed(reason string) {
	recorder.reasons = append(recorder.reasons, reason)
}

func equalReasons(actual, expected []string) bool {
	return strings.Join(actual, ",") == strings.Join(expected, ",")
}

func multipartBody(t *testing.T, field, name, value string) (*bytes.Buffer, string) {
	t.Helper()
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, err := writer.CreateFormFile(field, name)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := part.Write([]byte(value)); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	return body, writer.FormDataContentType()
}
