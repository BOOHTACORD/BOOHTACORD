package resetapi_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	sessionpostgres "voice-platform/backend/internal/identity/authenticate_session/postgres"
	"voice-platform/backend/internal/identity/complete_password_reset"
	completeapi "voice-platform/backend/internal/identity/complete_password_reset/api"
	completepostgres "voice-platform/backend/internal/identity/complete_password_reset/postgres"
	"voice-platform/backend/internal/identity/create_password_reset"
	createapi "voice-platform/backend/internal/identity/create_password_reset/api"
	createpostgres "voice-platform/backend/internal/identity/create_password_reset/postgres"
	"voice-platform/backend/internal/identity/login_user"
	loginapi "voice-platform/backend/internal/identity/login_user/api"
	loginpostgres "voice-platform/backend/internal/identity/login_user/postgres"
	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/session"
)

const oldResetPassword = "OldPass12345!"
const newResetPassword = "NewPass45678!"

type resetFlowFixture struct {
	server       *httptest.Server
	memberID     string
	adminCookie  *http.Cookie
	memberCookie *http.Cookie
}

func newResetFlowFixture(t *testing.T) resetFlowFixture {
	t.Helper()
	pool := newResetHTTPPool(t)
	ctx := context.Background()
	adminID, memberID := uuid.NewString(), uuid.NewString()
	oldHash, err := password.Hash(context.Background(), oldResetPassword)
	if err != nil {
		t.Fatal(err)
	}
	for _, user := range []struct{ id, login, role string }{
		{adminID, "qa02admin", "ADMINISTRATOR"},
		{memberID, "qa02member", "MEMBER"},
	} {
		if _, err := pool.Exec(ctx, `INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,$2,'QA user',$3,$4)`, user.id, user.login, oldHash, user.role); err != nil {
			t.Fatal(err)
		}
	}
	adminSession, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	memberSession, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	for _, active := range []struct {
		digest []byte
		id     string
	}{{adminSession.Digest[:], adminID}, {memberSession.Digest[:], memberID}} {
		if _, err := pool.Exec(ctx, `INSERT INTO sessions (token_digest,user_id) VALUES ($1,$2)`, active.digest, active.id); err != nil {
			t.Fatal(err)
		}
	}
	auth := authenticatesession.New(sessionpostgres.New(sessionpostgres.NewPoolDatabase(pool)))
	creator := createpasswordreset.New(createpostgres.New(createpostgres.NewPoolDatabase(pool)), time.Now)
	completer := completepasswordreset.New(completepostgres.New(completepostgres.NewPoolDatabase(pool)))
	loginStore := loginpostgres.New(loginpostgres.NewPoolDatabase(pool))
	loginer := loginuser.New(loginStore, loginStore)
	mux := http.NewServeMux()
	server := httptest.NewServer(mux)
	t.Cleanup(server.Close)
	mux.Handle("POST /api/v1/admin/password-reset-links", sessionapi.Require(auth)(sessionapi.RequireAdministrator(createapi.NewHandler(creator, server.URL))))
	mux.Handle("POST /api/v1/auth/password-reset/complete", completeapi.NewHandler(completer))
	mux.Handle("POST /api/v1/auth/login", loginapi.NewHandler(loginer))
	mux.Handle("GET /api/v1/auth/session", sessionapi.Require(auth)(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) { writer.WriteHeader(http.StatusNoContent) })))
	return resetFlowFixture{server: server, memberID: memberID,
		adminCookie:  &http.Cookie{Name: session.CookieName, Value: adminSession.Token},
		memberCookie: &http.Cookie{Name: session.CookieName, Value: memberSession.Token}}
}
