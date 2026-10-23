package loginapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	admitlogin "voice-platform/backend/internal/identity/admit_login"
	loginuser "voice-platform/backend/internal/identity/login_user"
	"voice-platform/backend/internal/identity/password"
	ratelimit "voice-platform/backend/internal/security/rate_limit"
)

func loginRequest(handler http.Handler, login, candidate, remote string) *httptest.ResponseRecorder {
	request := httptest.NewRequest("POST", "/api/v1/auth/login", strings.NewReader(`{"login":"`+login+`","password":"`+candidate+`"}`))
	request.RemoteAddr = remote
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}

func TestAdmissionRecoversWithoutPersistentLockAndKeepsNATBudgetsIndependent(t *testing.T) {
	now := time.Now()
	budget, _ := admitlogin.New(admitlogin.Config{Limit: 1, Window: 30 * time.Second, MaxAccounts: 4, Now: func() time.Time { return now }})
	calls := 0
	handler := NewHandlerWithAdmission(loginerFunc(func(_ context.Context, input loginuser.Input) (loginuser.Result, error) {
		calls++
		if input.Password == "correct" {
			return loginuser.Result{Token: "synthetic", ExpiresAt: time.Now().Add(time.Hour)}, nil
		}
		return loginuser.Result{}, loginuser.ErrInvalidCredentials
	}), budget)
	if response := loginRequest(handler, "SYNTHETIC-A", "wrong", "192.0.2.1:1"); response.Code != 401 {
		t.Fatal(response.Code)
	}
	if response := loginRequest(handler, "synthetic-a", "correct", "192.0.2.2:1"); response.Code != 429 || response.Header().Get("Retry-After") != "30" || response.Header().Get("Cache-Control") != "no-store" || calls != 1 {
		t.Fatal("denied request reached verifier or omitted retry")
	}
	if response := loginRequest(handler, "synthetic-b", "correct", "192.0.2.1:1"); response.Code != 204 {
		t.Fatal("independent account behind NAT was denied")
	}
	now = now.Add(29 * time.Second)
	if response := loginRequest(handler, "synthetic-a", "wrong", "192.0.2.3:1"); response.Code != 429 || response.Header().Get("Retry-After") != "1" {
		t.Fatal("denied requests extended window")
	}
	now = now.Add(time.Second)
	if response := loginRequest(handler, "synthetic-a", "correct", "192.0.2.4:1"); response.Code != 204 || len(response.Result().Cookies()) != 1 || calls != 3 {
		t.Fatal("legitimate login did not recover")
	}
}

func TestNetworkAdmissionStillRejectsEleventhRequestBeforeAccountWork(t *testing.T) {
	network, _ := ratelimit.New(ratelimit.Config{Limit: 10, Window: 5 * time.Minute, MaxSources: 8})
	budget, _ := admitlogin.New(admitlogin.Config{Limit: 20, Window: 30 * time.Second, MaxAccounts: 8})
	calls := 0
	handler := network.Middleware(NewHandlerWithAdmission(loginerFunc(func(context.Context, loginuser.Input) (loginuser.Result, error) {
		calls++
		return loginuser.Result{}, loginuser.ErrInvalidCredentials
	}), budget))
	for i := range 11 {
		response := loginRequest(handler, "synthetic-member", "wrong", "192.0.2.1:1")
		expected := 401
		if i == 10 {
			expected = 429
		}
		if response.Code != expected {
			t.Fatal("network limit changed")
		}
	}
	if calls != 10 {
		t.Fatal("eleventh source request reached account work")
	}
}

func TestStrictParsingAndCancellationNeverReachAccountWork(t *testing.T) {
	budget, _ := admitlogin.New(admitlogin.Config{Limit: 1, Window: 30 * time.Second, MaxAccounts: 2})
	calls := 0
	handler := NewHandlerWithAdmission(loginerFunc(func(context.Context, loginuser.Input) (loginuser.Result, error) {
		calls++
		return loginuser.Result{}, loginuser.ErrInvalidCredentials
	}), budget)
	for _, body := range []string{`{"login":"synthetic-member","password":"wrong","extra":true}`, `{"login":"synthetic-member","password":"wrong"} {}`, `{"login":"synthetic-member","password":"` + strings.Repeat("x", 8192) + `"}`} {
		request := httptest.NewRequest("POST", "/api/v1/auth/login", strings.NewReader(body))
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, request)
		if response.Code != 400 {
			t.Fatal("body/strict JSON boundary changed")
		}
	}
	for _, ctx := range []context.Context{cancelledContext(), expiredContext()} {
		request := httptest.NewRequest("POST", "/api/v1/auth/login", strings.NewReader(`{"login":"synthetic-member","password":"wrong"}`)).WithContext(ctx)
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, request)
		if response.Code != 500 || len(response.Result().Cookies()) != 0 {
			t.Fatal("cancelled request issued auth response")
		}
	}
	if calls != 0 || budget.Stats().Accounts != 0 {
		t.Fatal("unadmitted request reached account lookup or reserved a slot")
	}
}
func cancelledContext() context.Context {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	return ctx
}
func expiredContext() context.Context {
	ctx, cancel := context.WithDeadline(context.Background(), time.Unix(1, 0))
	cancel()
	return ctx
}

func TestBusyRefundsOnlyProvenUnstartedWork(t *testing.T) {
	for _, failure := range []error{password.ErrBusy, context.Canceled, context.DeadlineExceeded, errors.New("synthetic infrastructure failure")} {
		t.Run(map[bool]string{true: "busy", false: failure.Error()}[errors.Is(failure, password.ErrBusy)], func(t *testing.T) {
			budget, _ := admitlogin.New(admitlogin.Config{Limit: 1, Window: 30 * time.Second, MaxAccounts: 2})
			calls := 0
			handler := NewHandlerWithAdmission(loginerFunc(func(context.Context, loginuser.Input) (loginuser.Result, error) {
				calls++
				return loginuser.Result{}, failure
			}), budget)
			loginRequest(handler, "synthetic-member", "wrong", "192.0.2.1:1")
			response := loginRequest(handler, "synthetic-member", "correct", "192.0.2.2:1")
			if errors.Is(failure, password.ErrBusy) {
				if calls != 2 || response.Code != 503 {
					t.Fatal("KDF not-started refusal consumed account budget")
				}
			} else if calls != 1 || response.Code != 429 {
				t.Fatal("ambiguous cancellation/infra error refunded started work")
			}
			if budget.Stats().InFlight != 0 {
				t.Fatal("reservation leak")
			}
		})
	}
}
