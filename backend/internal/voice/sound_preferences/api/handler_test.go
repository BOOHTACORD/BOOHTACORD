package soundapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	session "voice-platform/backend/internal/identity/authenticate_session/api"
	p "voice-platform/backend/internal/voice/sound_preferences"
)

const actor = "11111111-1111-4111-8111-111111111111"

type fakeService struct {
	read  p.Snapshot
	saved p.Settings
	id    string
	calls int
	err   error
}

func (f *fakeService) Read(_ context.Context, id string) (p.Snapshot, error) {
	f.id = id
	return f.read, f.err
}
func (f *fakeService) Save(_ context.Context, id string, revision int64, v p.Settings) (p.Snapshot, error) {
	f.id = id
	f.calls++
	f.saved = v
	return p.Snapshot{Revision: revision + 1, Settings: v}, f.err
}
func request(h http.Handler, method, body string, signed bool) *httptest.ResponseRecorder {
	r := httptest.NewRequest(method, "/api/v1/me/voice-sound-preferences", strings.NewReader(body))
	if signed {
		r = r.WithContext(session.WithPrincipal(r.Context(), auth.Principal{AccountID: actor, Role: "MEMBER"}))
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	return w
}
func TestConsentEndpointRequiresSessionAndPatchesOnlySuppliedValues(t *testing.T) {
	f := &fakeService{read: p.Snapshot{Revision: 2, Settings: p.Default()}}
	h := NewHandler(f)
	if got := request(h, "GET", "", false).Code; got != 401 {
		t.Fatalf("anonymous=%d", got)
	}
	if got := request(h, "PATCH", `{"expected_revision":2,"joined":false}`, true).Code; got != 200 {
		t.Fatalf("patch=%d", got)
	}
	if f.id != actor || f.calls != 1 || f.saved.Joined || !f.saved.Left || !f.saved.Enabled {
		t.Fatal("actor or unrelated preferences changed")
	}
}
func TestConsentEndpointRejectsUnsafeBodiesAndStaleRevision(t *testing.T) {
	f := &fakeService{read: p.Snapshot{Revision: 2, Settings: p.Default()}}
	h := NewHandler(f)
	for _, body := range []string{`{"expected_revision":2,"account_id":"other"}`, `{"expected_revision":2,"volume":101}`, `{"expected_revision":2,"joined":false} {}`, `{"expected_revision":2}`, `{"joined":false}`} {
		if got := request(h, "PATCH", body, true).Code; got != 400 {
			t.Fatalf("invalid body accepted: %d", got)
		}
	}
	if got := request(h, "PATCH", `{"expected_revision":1,"joined":false}`, true).Code; got != 409 {
		t.Fatalf("stale=%d", got)
	}
	if f.calls != 0 {
		t.Fatal("invalid update reached storage")
	}
	f.err = p.ErrConflict
	if got := request(h, "GET", "", true).Code; got == 200 {
		t.Fatal("storage failure hidden")
	}
}

func TestReadResponseIsPrivateAndUsesStableKeys(t *testing.T) {
	f := &fakeService{read: p.Snapshot{Revision: 2, Settings: p.Default()}}
	w := request(NewHandler(f), "GET", "", true)
	if w.Code != 200 || w.Header().Get("Cache-Control") != "no-store" || !strings.Contains(w.Body.String(), `"revision":2`) || !strings.Contains(w.Body.String(), `"settings":`) {
		t.Fatalf("bad private response: status=%d", w.Code)
	}
}

func TestAccountFenceRejectsAccountSwitch(t *testing.T) {
	f := &fakeService{read: p.Snapshot{Revision: 1, Settings: p.Default()}}
	r := httptest.NewRequest("PATCH", "/api/v1/me/voice-sound-preferences", strings.NewReader(`{"expected_revision":1,"joined":false}`))
	r = r.WithContext(session.WithPrincipal(r.Context(), auth.Principal{AccountID: actor, Role: "MEMBER"}))
	r.Header.Set("X-Voice-Sound-Account", "22222222-2222-4222-8222-222222222222")
	w := httptest.NewRecorder()
	NewHandler(f).ServeHTTP(w, r)
	if w.Code != 409 || f.calls != 0 || f.id != "" {
		t.Fatal("mismatched session account reached storage")
	}
}

func TestPatchRejectsExplicitNullRatherThanSilentlyIgnoringIt(t *testing.T) {
	f := &fakeService{read: p.Snapshot{Revision: 2, Settings: p.Default()}}
	if got := request(NewHandler(f), "PATCH", `{"expected_revision":2,"joined":false,"left":null}`, true).Code; got != 400 || f.calls != 0 {
		t.Fatal("null field accepted")
	}
}
