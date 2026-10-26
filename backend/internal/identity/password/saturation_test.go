package password_test

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	change "voice-platform/backend/internal/identity/change_own_password"
	changeapi "voice-platform/backend/internal/identity/change_own_password/api"
	reset "voice-platform/backend/internal/identity/complete_password_reset"
	resetapi "voice-platform/backend/internal/identity/complete_password_reset/api"
	login "voice-platform/backend/internal/identity/login_user"
	loginapi "voice-platform/backend/internal/identity/login_user/api"
	"voice-platform/backend/internal/identity/password"
	register "voice-platform/backend/internal/identity/register_user"
	registerapi "voice-platform/backend/internal/identity/register_user/api"
	"voice-platform/backend/internal/identity/session"
)

func TestAllPasswordHTTPPathsRejectCapacityWithoutKDFOrMutation(t *testing.T) {
	hash, err := password.Hash(context.Background(), "synthetic correct password")
	if err != nil {
		t.Fatal("cannot prepare synthetic hash")
	}
	issued, err := session.Issue()
	if err != nil {
		t.Fatal("cannot prepare synthetic reset")
	}
	for _, kind := range []string{"known", "unknown", "blocked", "register", "reset", "change"} {
		t.Run(kind, func(t *testing.T) {
			mutations := 0
			accounts := privacyAccounts{account: login.Account{ID: "synthetic-account", PasswordHash: hash, Blocked: kind == "blocked"}}
			if kind == "unknown" {
				accounts.err = login.ErrAccountNotFound
			}
			sessions := &privacySessions{}
			var handler http.Handler = loginapi.NewHandler(login.New(accounts, sessions))
			body := map[string]string{"login": "synthetic-user", "password": "synthetic correct password"}
			switch kind {
			case "register":
				handler = registerapi.NewHandler(register.New(saturationRegisterStore{&mutations}))
			case "reset":
				handler = resetapi.NewHandler(reset.New(saturationResetStore{&mutations}))
				body = map[string]string{"token": issued.Token, "password": "synthetic replacement password"}
			case "change":
				handler = changeapi.NewHandler(change.New(saturationChangeStore{hash, &mutations}))
				body = map[string]string{"current_password": "synthetic correct password", "new_password": "synthetic replacement password"}
			}
			password.SaturateForTest(t)
			count := password.CountDerivationsForTest(t)
			encoded, _ := json.Marshal(body)
			request := httptest.NewRequest(http.MethodPost, "/synthetic-auth-path", strings.NewReader(string(encoded)))
			request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "synthetic-account", SessionDigest: sha256.Sum256([]byte("synthetic-cookie"))}))
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)
			var decoded struct {
				Error struct{ Code, Message string }
			}
			if err := json.Unmarshal(response.Body.Bytes(), &decoded); err != nil {
				t.Fatal("missing safe auth error")
			}
			if response.Code != 503 || response.Header().Get("Retry-After") != "1" || decoded.Error.Code != "AUTH_BUSY" || !strings.Contains(decoded.Error.Message, "вручную через 1 с.") || len(response.Result().Cookies()) != 0 || count() != 0 || mutations != 0 || sessions.created != 0 {
				t.Fatalf("capacity response: status=%d KDF=%d mutations=%d sessions=%d", response.Code, count(), mutations, sessions.created)
			}
		})
	}
}

type saturationRegisterStore struct{ mutations *int }

func (s saturationRegisterStore) Create(context.Context, register.Account) error {
	*s.mutations++
	return nil
}

type saturationResetStore struct{ mutations *int }

func (s saturationResetStore) Consume(context.Context, [sha256.Size]byte, string) error {
	*s.mutations++
	return nil
}

type saturationChangeStore struct {
	hash      string
	mutations *int
}

func (s saturationChangeStore) FindPasswordHash(context.Context, string) (string, error) {
	return s.hash, nil
}
func (s saturationChangeStore) ChangePassword(context.Context, string, string, string, [sha256.Size]byte) error {
	*s.mutations++
	return nil
}

func (s saturationResetStore) Preflight(context.Context, [sha256.Size]byte) error { return nil }
