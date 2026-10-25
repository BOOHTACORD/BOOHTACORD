package preferencesapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	p "voice-platform/backend/internal/notifications/preferences"
)

const actor = "11111111-1111-4111-8111-111111111111"

type fakeService struct {
	settings p.Settings
	input    p.Input
	writes   int
	err      error
}

func (s *fakeService) Read(context.Context, string) (p.Settings, error) { return s.settings, s.err }
func (s *fakeService) Save(_ context.Context, in p.Input) (p.Settings, error) {
	s.input = in
	s.writes++
	out := in.Settings
	out.Revision = 2
	return out, s.err
}

type fakeAccess bool

func (a fakeAccess) Allowed(context.Context, string, p.Override) (bool, error) { return bool(a), nil }

type spy struct {
	account  string
	revision int64
	calls    int
}

func (s *spy) Changed(a string, r int64) { s.account = a; s.revision = r; s.calls++ }
func request(handler http.Handler, method, path, body string, authenticated bool) *httptest.ResponseRecorder {
	r := httptest.NewRequest(method, path, strings.NewReader(body))
	if authenticated {
		r = r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: actor, Role: "ADMINISTRATOR"}))
	}
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, r)
	return w
}
func updateBody(s p.Settings) string {
	b, _ := json.Marshal(map[string]any{"expected_revision": 0, "settings": s})
	return string(b)
}

func TestAPIUnauthorizedAndUnknownFields(t *testing.T) {
	s := &fakeService{settings: p.Default()}
	h := NewHandler(s, fakeAccess(true), false, nil)
	if w := request(h, "GET", "/api/v1/notification-preferences", "", false); w.Code != 401 {
		t.Fatal(w.Code)
	}
	for _, body := range []string{`{"account_id":"other"}`, updateBody(p.Default()) + ` {}`, `{bad`} {
		if w := request(h, "PUT", "/api/v1/notification-preferences", body, true); w.Code != 400 {
			t.Fatalf("status=%d body=%s", w.Code, w.Body.String())
		}
	}
	if s.writes != 0 {
		t.Fatal("invalid request reached storage")
	}
}

func TestOwnWriteAndPrivateRevisionHint(t *testing.T) {
	s := &fakeService{settings: p.Default()}
	events := &spy{}
	h := NewHandler(s, fakeAccess(true), false, events)
	w := request(h, "PUT", "/api/v1/notification-preferences", updateBody(p.Default()), true)
	if w.Code != 200 || s.input.AccountID != actor || events.account != actor || events.revision != 2 || events.calls != 1 {
		t.Fatalf("status=%d input=%+v events=%+v", w.Code, s.input, events)
	}
	if w.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("private response cacheable")
	}
}

func TestConflictDoesNotPublishAndImportDoesNotEnable(t *testing.T) {
	s := &fakeService{err: p.ErrConflict}
	events := &spy{}
	h := NewHandler(s, fakeAccess(true), true, events)
	if w := request(h, "PUT", "/api/v1/notification-preferences", updateBody(p.Default()), true); w.Code != 409 || events.calls != 0 {
		t.Fatal(w.Code, events)
	}
	s.err = nil
	w := request(h, "POST", "/api/v1/notification-preferences/import", `{"expected_revision":0,"overrides":[],"local_disabled":true}`, true)
	if w.Code != 200 || !s.input.Import || s.input.Settings.Enabled {
		t.Fatal(w.Code, s.input)
	}
}
