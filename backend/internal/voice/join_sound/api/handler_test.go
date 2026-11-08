package joinsoundapi

import (
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	session "voice-platform/backend/internal/identity/authenticate_session/api"
	cookies "voice-platform/backend/internal/identity/session"
	s "voice-platform/backend/internal/voice/join_sound"
	downloadapi "voice-platform/backend/internal/voice/join_sound/download_api"
)

const account = "11111111-1111-4111-8111-111111111111"

type authenticator struct{}

func (authenticator) Authenticate(context.Context, string) (auth.Principal, error) {
	return auth.Principal{AccountID: account, ExpiresAt: time.Now().Add(time.Hour)}, nil
}

type service struct {
	actor   s.Actor
	uploads int
}

func (v *service) Upload(_ context.Context, a s.Actor, _ []byte) (s.Sound, error) {
	v.actor = a
	v.uploads++
	return s.Sound{ID: account, Revision: 1, Enabled: true}, nil
}
func (v *service) Download(_ context.Context, a s.Actor, _ string) (s.Sound, error) {
	v.actor = a
	return s.Sound{Audio: s.Audio{Bytes: []byte{1, 2}}}, nil
}
func (*service) Current(context.Context, s.Actor) (s.Sound, error)      { return s.Sound{}, s.ErrNotFound }
func (*service) Enable(context.Context, s.Actor, bool) (s.Sound, error) { return s.Sound{}, nil }
func (*service) Delete(context.Context, s.Actor) error                  { return nil }
func TestRoutesRequireSessionAndAccountFence(t *testing.T) {
	v := &service{}
	h := session.Require(authenticator{})(NewHandler(v))
	for _, x := range []struct {
		cookie, fence bool
		want          int
	}{{false, false, 401}, {true, false, 409}, {true, true, 201}} {
		r := httptest.NewRequest("POST", "/api/v1/me/join-sound", bytes.NewReader([]byte{1}))
		if x.cookie {
			r.AddCookie(&http.Cookie{Name: cookies.CookieName, Value: "qa"})
		}
		if x.fence {
			r.Header.Set("X-Voice-Sound-Account", account)
		}
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		if w.Code != x.want {
			t.Fatalf("status %d want %d", w.Code, x.want)
		}
	}
	if v.uploads != 1 || v.actor.Account != account {
		t.Fatal("authenticated ownership lost")
	}
}
func TestUploadIsBoundedAndPrivateDownloadCannotBeCached(t *testing.T) {
	v := &service{}
	h := session.Require(authenticator{})(NewHandler(v))
	r := httptest.NewRequest("POST", "/api/v1/me/join-sound", bytes.NewReader(make([]byte, s.MaxInput+1)))
	r.AddCookie(&http.Cookie{Name: cookies.CookieName, Value: "qa"})
	r.Header.Set("X-Voice-Sound-Account", account)
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != 413 || v.uploads != 0 {
		t.Fatal("oversize upload reached processor")
	}
	r = httptest.NewRequest("GET", "/api/v1/voice/join-sounds/"+account, nil)
	r.SetPathValue("id", account)
	r.AddCookie(&http.Cookie{Name: cookies.CookieName, Value: "qa"})
	w = httptest.NewRecorder()
	session.Require(authenticator{})(downloadapi.NewDownloadHandler(v)).ServeHTTP(w, r)
	if w.Code != 200 || w.Header().Get("Content-Type") != "audio/mpeg" || w.Header().Get("Cache-Control") != "no-store" || w.Header().Get("X-Content-Type-Options") != "nosniff" {
		t.Fatal("private audio response invalid")
	}
}
