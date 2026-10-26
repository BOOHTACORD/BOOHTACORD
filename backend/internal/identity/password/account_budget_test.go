package password_test

import (
	"context"
	"testing"
	"time"
	admitlogin "voice-platform/backend/internal/identity/admit_login"
	loginuser "voice-platform/backend/internal/identity/login_user"
	loginapi "voice-platform/backend/internal/identity/login_user/api"
	"voice-platform/backend/internal/identity/password"
)

func TestAccountBudgetPreventsFurtherNativeKDFAndSessions(t *testing.T) {
	encoded, err := password.Hash(context.Background(), "synthetic correct password")
	if err != nil {
		t.Fatal(err)
	}
	for _, kind := range []string{"known", "unknown", "blocked"} {
		t.Run(kind, func(t *testing.T) {
			accounts := privacyAccounts{account: loginuser.Account{ID: "synthetic-account", PasswordHash: encoded, Blocked: kind == "blocked"}}
			if kind == "unknown" {
				accounts.err = loginuser.ErrAccountNotFound
			}
			sessions := &privacySessions{}
			limiter, err := admitlogin.New(admitlogin.Config{Limit: 8, Window: 30 * time.Second, MaxAccounts: 16})
			if err != nil {
				t.Fatal(err)
			}
			handler := loginapi.NewHandlerWithAdmission(loginuser.New(accounts, sessions), limiter)
			count := password.CountDerivationsForTest(t)
			for index := range 12 {
				response := loginResponse(handler, "synthetic wrong password")
				expected := 401
				if index >= 8 {
					expected = 429
				}
				if response.Code != expected {
					t.Fatalf("attempt=%d status=%d", index, response.Code)
				}
			}
			response := loginResponse(handler, "synthetic correct password")
			if response.Code != 429 || count() != 8 || sessions.created != 0 || len(response.Result().Cookies()) != 0 {
				t.Fatalf("status=%d KDF=%d sessions=%d cookies=%d; want 429/8/0/0", response.Code, count(), sessions.created, len(response.Result().Cookies()))
			}
		})
	}
}
