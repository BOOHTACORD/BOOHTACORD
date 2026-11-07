package voicesoundroutes

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	origincheck "voice-platform/backend/internal/security/origin_check"
	p "voice-platform/backend/internal/voice/sound_preferences"
)

type authStub struct{}

func (authStub) Authenticate(context.Context, string) (auth.Principal, error) {
	return auth.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "MEMBER", ExpiresAt: time.Now().Add(time.Hour)}, nil
}

type serviceStub struct{}

func (serviceStub) Read(context.Context, string) (p.Snapshot, error) {
	return p.Snapshot{Settings: p.Default()}, nil
}
func (serviceStub) Save(_ context.Context, _ string, r int64, v p.Settings) (p.Snapshot, error) {
	return p.Snapshot{Revision: r + 1, Settings: v}, nil
}
func TestRoutesRequireSession(t *testing.T) {
	mux := http.NewServeMux()
	Register(mux, serviceStub{}, authStub{})
	for _, method := range []string{"GET", "PATCH"} {
		r := httptest.NewRequest(method, "/api/v1/me/voice-sound-preferences", nil)
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, r)
		if w.Code != 401 {
			t.Fatalf("%s without session: %d", method, w.Code)
		}
	}
	r := httptest.NewRequest("GET", "/api/v1/me/voice-sound-preferences", nil)
	r.AddCookie(&http.Cookie{Name: session.CookieName, Value: "qa"})
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, r)
	if w.Code != 200 {
		t.Fatalf("authenticated: %d", w.Code)
	}
}

func TestMutationRequiresExactOrigin(t *testing.T) {
	mux := http.NewServeMux()
	Register(mux, serviceStub{}, authStub{})
	wrap, err := origincheck.New("https://voice.example.test")
	if err != nil {
		t.Fatal(err)
	}
	for _, item := range []struct {
		origin string
		want   int
	}{{"", 403}, {"https://evil.test", 403}, {"https://voice.example.test", 200}} {
		r := httptest.NewRequest("PATCH", "/api/v1/me/voice-sound-preferences", strings.NewReader(`{"expected_revision":0,"joined":false}`))
		r.AddCookie(&http.Cookie{Name: session.CookieName, Value: "qa"})
		r.Header.Set("Origin", item.origin)
		w := httptest.NewRecorder()
		wrap(mux).ServeHTTP(w, r)
		if w.Code != item.want {
			t.Fatalf("origin result=%d want=%d", w.Code, item.want)
		}
	}
}
