package screenpreviewapi

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"voice-platform/backend/internal/identity/session"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

func TestUploadRouteRejectsClientFramesWithoutReadingOrForwardingTheBody(t *testing.T) {
	ops := &operationsStub{}
	mux := http.NewServeMux()
	RegisterRoutes(mux, authStub{}, ops)
	path := "/api/v1/voice/leases/12f2f7b4-59ca-430e-883e-f9fab5c6c56f/screen-previews/v1/7e78d5a0-1ba9-4c18-b268-8b03e3c6e5f0"
	request := httptest.NewRequest(http.MethodPut, path, bytes.NewReader(make([]byte, screenpreview.MaxJPEGBytes+1)))
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	request.Header.Set("Content-Type", "image/jpeg")
	request.Header.Set("X-Screen-Preview-Revision", "1")
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusGone || ops.uploads != 0 {
		t.Fatalf("legacy upload = %d, calls=%d", response.Code, ops.uploads)
	}
	assertPrivateHeaders(t, response)
	request = httptest.NewRequest(http.MethodPut, path, bytes.NewReader([]byte("<svg/>")))
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	request.Header.Set("Content-Type", "image/svg+xml")
	request.Header.Set("X-Screen-Preview-Revision", "1")
	response = httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusGone || ops.uploads != 0 {
		t.Fatalf("legacy upload with wrong MIME = %d, calls=%d", response.Code, ops.uploads)
	}
	request = httptest.NewRequest(http.MethodPut, path, bytes.NewReader([]byte("")))
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	request.Header.Set("Content-Type", "image/jpeg")
	response = httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusGone || ops.uploads != 0 {
		t.Fatalf("legacy upload without revision = %d, calls=%d", response.Code, ops.uploads)
	}
}
