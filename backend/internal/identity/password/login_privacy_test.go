package password_test

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	loginuser "voice-platform/backend/internal/identity/login_user"
	loginapi "voice-platform/backend/internal/identity/login_user/api"
	"voice-platform/backend/internal/identity/password"
	ratelimit "voice-platform/backend/internal/security/rate_limit"
)

func TestSecurity20261022UnknownVersusKnownWork(t *testing.T) {
	encoded, err := password.Hash(context.Background(), "synthetic correct password")
	if err != nil {
		t.Fatal("cannot prepare synthetic account")
	}
	for _, test := range []struct {
		name, candidate           string
		unknown, blocked, corrupt bool
		status, sessions          int
		code                      string
		work                      int64
	}{
		{name: "known wrong", candidate: "synthetic wrong password", status: 401, code: "UNAUTHENTICATED", work: 1},
		{name: "unknown", candidate: "synthetic wrong password", unknown: true, status: 401, code: "UNAUTHENTICATED", work: 1},
		{name: "unknown dummy secret", candidate: "unmatchable-dummy-password", unknown: true, status: 401, code: "UNAUTHENTICATED", work: 1},
		{name: "blocked wrong", candidate: "synthetic wrong password", blocked: true, status: 401, code: "UNAUTHENTICATED", work: 1},
		{name: "blocked correct", candidate: "synthetic correct password", blocked: true, status: 403, code: "ACCOUNT_BLOCKED", work: 1},
		{name: "known correct", candidate: "synthetic correct password", status: 204, sessions: 1, work: 1},
		{name: "corrupt user hash", candidate: "synthetic correct password", corrupt: true, status: 500, code: "INTERNAL"},
	} {
		t.Run(test.name, func(t *testing.T) {
			accounts := privacyAccounts{account: loginuser.Account{ID: "synthetic-account", PasswordHash: encoded, Blocked: test.blocked}}
			if test.unknown {
				accounts.err = loginuser.ErrAccountNotFound
			}
			if test.corrupt {
				accounts.account.PasswordHash = "synthetic malformed hash"
			}
			sessions := &privacySessions{}
			count := password.CountDerivationsForTest(t)
			response := loginResponse(loginapi.NewHandler(loginuser.New(accounts, sessions)), test.candidate)
			if response.Code != test.status || sessions.created != test.sessions || len(response.Result().Cookies()) != test.sessions || count() != test.work {
				t.Fatalf("status=%d sessions=%d cookies=%d KDF=%d; want %d/%d/%d/%d", response.Code, sessions.created, len(response.Result().Cookies()), count(), test.status, test.sessions, test.sessions, test.work)
			}
			if test.code != "" {
				var body struct {
					Error struct{ Code, Message, RequestID string }
				}
				if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil || body.Error.Code != test.code {
					t.Fatal("unexpected public error contract")
				}
				if test.status == 401 && body.Error.Message != "Неверный логин или пароль" {
					t.Fatal("negative login must use the same public message")
				}
			}
		})
	}
}

func TestSecurity20261022IPAdmissionRejectsWithoutKDF(t *testing.T) {
	encoded, err := password.Hash(context.Background(), "synthetic correct password")
	if err != nil {
		t.Fatal("cannot prepare synthetic account")
	}
	for _, unknown := range []bool{false, true} {
		t.Run(map[bool]string{false: "known", true: "unknown"}[unknown], func(t *testing.T) {
			limiter, err := ratelimit.New(ratelimit.Config{Limit: 1, Window: time.Minute, MaxSources: 16})
			if err != nil {
				t.Fatal(err)
			}
			accounts := privacyAccounts{account: loginuser.Account{ID: "synthetic-account", PasswordHash: encoded}}
			if unknown {
				accounts.err = loginuser.ErrAccountNotFound
			}
			sessions := &privacySessions{}
			handler := limiter.Middleware(loginapi.NewHandler(loginuser.New(accounts, sessions)))
			count := password.CountDerivationsForTest(t)
			if response := loginResponse(handler, "synthetic wrong password"); response.Code != 401 || count() != 1 {
				t.Fatal("admitted negative request must perform exactly one KDF")
			}
			response := loginResponse(handler, "synthetic correct password")
			if response.Code != 429 || response.Header().Get("Retry-After") != "60" || count() != 1 || sessions.created != 0 || len(response.Result().Cookies()) != 0 {
				t.Fatal("network admission must reject without KDF or session")
			}
		})
	}
}

func TestCorruptDummyFailsClosedThroughLogin(t *testing.T) {
	password.CorruptDummyForTest(t)
	count := password.CountDerivationsForTest(t)
	sessions := &privacySessions{}
	response := loginResponse(loginapi.NewHandler(loginuser.New(privacyAccounts{err: loginuser.ErrAccountNotFound}, sessions)), "synthetic password")
	if response.Code != 500 || count() != 0 || sessions.created != 0 || len(response.Result().Cookies()) != 0 || strings.Contains(response.Body.String(), "hash") {
		t.Fatal("corrupt dummy must surface as a safe infrastructure failure without a session")
	}
}

func loginResponse(handler http.Handler, candidate string) *httptest.ResponseRecorder {
	body, _ := json.Marshal(map[string]string{"login": "synthetic-user", "password": candidate})
	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(string(body)))
	request.RemoteAddr = "192.0.2.1:1234"
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}

type privacyAccounts struct {
	account loginuser.Account
	err     error
}

func (accounts privacyAccounts) FindByLogin(context.Context, string) (loginuser.Account, error) {
	return accounts.account, accounts.err
}

type privacySessions struct{ created int }

func (sessions *privacySessions) Create(context.Context, string, [sha256.Size]byte, time.Time) error {
	sessions.created++
	return nil
}
