package supportcontact

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	session "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type consenter struct {
	actor   string
	version int
	calls   int
}

func (c *consenter) Accept(_ context.Context, actor string, version int) error {
	c.calls++
	c.actor = actor
	c.version = version
	return nil
}
func TestConsentRequiresAuthenticatedExplicitVersion(t *testing.T) {
	for _, row := range []struct {
		body          string
		authenticated bool
		status        int
	}{
		{`{"notice_version":1}`, false, 401}, {`{}`, true, 400}, {`{"notice_version":true}`, true, 400}, {`{"notice_version":1,"user_id":"other"}`, true, 400}, {`{"notice_version":1} {}`, true, 400}, {`{"notice_version":1}`, true, 204},
	} {
		service := &consenter{}
		request := httptest.NewRequest(http.MethodPost, "/api/v1/support/consent", strings.NewReader(row.body))
		if row.authenticated {
			request = request.WithContext(sessionapi.WithPrincipal(request.Context(), session.Principal{AccountID: actor}))
		}
		response := httptest.NewRecorder()
		ConsentHandler(service).ServeHTTP(response, request)
		if response.Code != row.status {
			t.Fatalf("consent response %d expected %d", response.Code, row.status)
		}
		if row.status == 204 && (service.calls != 1 || service.actor != actor || service.version != 1) {
			t.Fatal("consent not bound to caller")
		}
		if row.status != 204 && service.calls != 0 {
			t.Fatal("invalid consent reached storage")
		}
	}
}
