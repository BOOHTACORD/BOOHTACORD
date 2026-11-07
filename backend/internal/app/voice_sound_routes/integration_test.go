package voicesoundroutes

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	"voice-platform/backend/internal/identity/session"
	origin "voice-platform/backend/internal/security/origin_check"
	fixture "voice-platform/backend/internal/testsupport/postgres"
	p "voice-platform/backend/internal/voice/sound_preferences"
	db "voice-platform/backend/internal/voice/sound_preferences/postgres"
)

func TestAuthenticatedRoutePersistsAndRejectsStalePatch(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES('11111111-1111-4111-8111-111111111111','sound-route','Sound','test','MEMBER')`); err != nil {
		t.Fatal(err)
	}
	mux := http.NewServeMux()
	Register(mux, p.New(db.New(pool)), authStub{})
	wrap, err := origin.New("https://voice.example.test")
	if err != nil {
		t.Fatal(err)
	}
	send := func(method, body string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(method, "/api/v1/me/voice-sound-preferences", strings.NewReader(body))
		r.AddCookie(&http.Cookie{Name: session.CookieName, Value: "qa"})
		r.Header.Set("Origin", "https://voice.example.test")
		r.Header.Set("X-Voice-Sound-Account", "11111111-1111-4111-8111-111111111111")
		w := httptest.NewRecorder()
		wrap(mux).ServeHTTP(w, r)
		return w
	}
	first := send("PATCH", `{"expected_revision":0,"joined":false}`)
	if first.Code != 200 {
		t.Fatalf("save status=%d", first.Code)
	}
	stale := send("PATCH", `{"expected_revision":0,"joined":true}`)
	if stale.Code != 409 {
		t.Fatalf("stale status=%d", stale.Code)
	}
	read := send("GET", "")
	if read.Code != 200 || !strings.Contains(read.Body.String(), `"joined":false`) || !strings.Contains(read.Body.String(), `"revision":1`) {
		t.Fatalf("read status=%d", read.Code)
	}
}
