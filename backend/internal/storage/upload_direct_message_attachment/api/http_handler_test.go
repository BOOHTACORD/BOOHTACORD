package uploaddirectmessageattachmentapi

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
	authorize "voice-platform/backend/internal/storage/authorize_direct_message_attachment"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
	upload "voice-platform/backend/internal/storage/upload_direct_message_attachment"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

func TestHandlerForwardsPrivateMultipartAndMapsFailures(t *testing.T) {
	for _, test := range []struct {
		err    error
		status int
		code   string
	}{
		{nil, 201, `"id":"attachment"`},
		{authorize.ErrTargetUnavailable, 404, `"NOT_FOUND"`},
		{authorize.ErrInvalidInput, 404, `"NOT_FOUND"`},
		{reserve.ErrInsufficientStorage, 507, `"INSUFFICIENT_STORAGE"`},
		{writeupload.ErrTooLarge, 413, `"ATTACHMENT_TOO_LARGE"`},
		{errors.New("private-key"), 500, `"INTERNAL"`},
	} {
		body := &bytes.Buffer{}
		writer := multipart.NewWriter(body)
		part, _ := writer.CreateFormFile("file", "name.txt")
		_, _ = part.Write([]byte("abc"))
		_ = writer.Close()
		uploader := &fakeUploader{err: test.err}
		request := httptest.NewRequest(http.MethodPost, "/api/v1/direct-messages/pair/attachments", body)
		request.Header.Set("Content-Type", writer.FormDataContentType())
		request.SetPathValue("directMessageID", "pair")
		request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "actor", Role: "ADMINISTRATOR"}))
		response := newDeadlineRecorder()
		NewHandler(uploader, &fakeFailureRecorder{}).ServeHTTP(response, request)
		if response.Code != test.status || !strings.Contains(response.Body.String(), test.code) || strings.Contains(response.Body.String(), "private-key") || uploader.input.DirectMessageID != "pair" {
			t.Fatalf("status=%d body=%q input=%#v", response.Code, response.Body.String(), uploader.input)
		}
	}
}

type fakeUploader struct {
	input upload.Input
	err   error
}

func (uploader *fakeUploader) Upload(_ context.Context, input upload.Input) (upload.Result, error) {
	uploader.input = input
	return upload.Result{ID: "attachment", OriginalName: input.OriginalName, SizeBytes: 3}, uploader.err
}

type fakeFailureRecorder struct{}

func (*fakeFailureRecorder) UploadFailed(string) {}
