package uploaddirectmessageattachmentapi

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type deadlineRecorder struct{ *httptest.ResponseRecorder }

func newDeadlineRecorder() *deadlineRecorder              { return &deadlineRecorder{httptest.NewRecorder()} }
func (*deadlineRecorder) SetReadDeadline(time.Time) error { return nil }

func TestHandlerFailsClosedBeforeReadWhenDeadlineUnsupported(t *testing.T) {
	source := &unreadBody{}
	request := httptest.NewRequest(http.MethodPost, "/", nil)
	request.Body = source
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "actor"}))
	response := httptest.NewRecorder()
	uploader := &fakeUploader{}
	NewHandler(uploader, &fakeFailureRecorder{}).ServeHTTP(response, request)
	if response.Code != http.StatusInternalServerError || response.Header().Get("Connection") != "close" || !strings.Contains(response.Body.String(), "INTERNAL") || source.read || uploader.input.ActorID != "" {
		t.Fatalf("unsupported writer was not rejected before source/uploader: status=%d read=%v", response.Code, source.read)
	}
}

type unreadBody struct{ read bool }

func (body *unreadBody) Read([]byte) (int, error) { body.read = true; return 0, io.EOF }
func (*unreadBody) Close() error                  { return nil }
