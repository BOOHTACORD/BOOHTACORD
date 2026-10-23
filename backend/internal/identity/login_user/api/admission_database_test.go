package loginapi_test

import (
	"context"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"
	"voice-platform/backend/internal/database/migrate"
	admitlogin "voice-platform/backend/internal/identity/admit_login"
	loginuser "voice-platform/backend/internal/identity/login_user"
	loginapi "voice-platform/backend/internal/identity/login_user/api"
	loginpostgres "voice-platform/backend/internal/identity/login_user/postgres"
	"voice-platform/backend/internal/identity/password"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

type observedAccounts struct {
	repository loginpostgres.Repository
	calls      atomic.Int32
}

func (accounts *observedAccounts) FindByLogin(ctx context.Context, login string) (loginuser.Account, error) {
	accounts.calls.Add(1)
	return accounts.repository.FindByLogin(ctx, login)
}

func TestAccountAdmissionRejectsWithoutPostgresSessionAndRecovers(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	encoded, err := password.Hash(ctx, "synthetic correct password")
	if err != nil {
		t.Fatal(err)
	}
	id := uuid.NewString()
	if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'synthetic-member','Synthetic account',$2,'MEMBER')`, id, encoded); err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	budget, _ := admitlogin.New(admitlogin.Config{Limit: 1, Window: 30 * time.Second, MaxAccounts: 4, Now: func() time.Time { return now }})
	repository := loginpostgres.New(loginpostgres.NewPoolDatabase(pool))
	accounts := &observedAccounts{repository: repository}
	handler := loginapi.NewHandlerWithAdmission(loginuser.New(accounts, repository), budget)
	request := func(candidate string) *httptest.ResponseRecorder {
		req := httptest.NewRequest("POST", "/api/v1/auth/login", strings.NewReader(`{"login":"SYNTHETIC-MEMBER","password":"`+candidate+`"}`))
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, req)
		return response
	}
	if response := request("synthetic wrong password"); response.Code != 401 {
		t.Fatal("initial negative login failed")
	}
	for range 4 {
		response := request("synthetic correct password")
		if response.Code != 429 || len(response.Result().Cookies()) != 0 {
			t.Fatal("account budget failed to reject before verifier")
		}
	}
	var sessions int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM sessions`).Scan(&sessions); err != nil || sessions != 0 || accounts.calls.Load() != 1 {
		t.Fatal("denied login performed account lookup/session mutation")
	}
	now = now.Add(30 * time.Second)
	response := request("synthetic correct password")
	if response.Code != 204 || len(response.Result().Cookies()) != 1 {
		t.Fatal("legitimate login did not recover after fixed window")
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM sessions WHERE user_id=$1`, id).Scan(&sessions); err != nil || sessions != 1 || accounts.calls.Load() != 2 {
		t.Fatal("recovered login did not persist exactly one session")
	}
}
