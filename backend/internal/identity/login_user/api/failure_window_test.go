package loginapi

import (
	"context"
	"testing"
	"time"
	admitlogin "voice-platform/backend/internal/identity/admit_login"
	loginuser "voice-platform/backend/internal/identity/login_user"
	failures "voice-platform/backend/internal/identity/track_login_failures"
)

func TestSeparateFailureWindowAcrossGeneralWindowBoundary(t *testing.T) {
	now := time.Now()
	clock := func() time.Time { return now }
	general, _ := admitlogin.New(admitlogin.Config{Limit: 8, Window: 30 * time.Second, MaxAccounts: 16, Now: clock})
	failure, _ := failures.New(failures.Config{Limit: 8, Window: 30 * time.Second, Capacity: 16, Now: clock})
	calls := 0
	handler := NewHandlerWithAdmissionAndFailures(loginerFunc(func(_ context.Context, input loginuser.Input) (loginuser.Result, error) {
		calls++
		if input.Password == "valid" {
			return loginuser.Result{Token: "synthetic", ExpiresAt: time.Now().Add(time.Hour)}, nil
		}
		return loginuser.Result{}, loginuser.ErrInvalidCredentials
	}), general, failure)
	if got := loginRequest(handler, "SYNTHETIC-A", "valid", "192.0.2.1:1"); got.Code != 204 {
		t.Fatal(got.Code)
	}
	now = now.Add(29 * time.Second)
	for range 7 {
		if got := loginRequest(handler, "synthetic-a", "wrong", "192.0.2.2:1"); got.Code != 401 {
			t.Fatal(got.Code)
		}
	}
	now = now.Add(time.Second)
	if got := loginRequest(handler, "synthetic-a", "wrong", "192.0.2.3:1"); got.Code != 401 {
		t.Fatal(got.Code)
	}
	if got := loginRequest(handler, "synthetic-a", "valid", "192.0.2.4:1"); got.Code != 429 || got.Header().Get("Retry-After") != "29" || len(got.Result().Cookies()) != 0 || calls != 9 {
		t.Fatal("separate failed-attempt window was bypassed")
	}
	if got := loginRequest(handler, "synthetic-b", "valid", "192.0.2.4:1"); got.Code != 204 {
		t.Fatal("neighbor rejected")
	}
	now = now.Add(29 * time.Second)
	if got := loginRequest(handler, "synthetic-a", "valid", "192.0.2.4:1"); got.Code != 204 {
		t.Fatal("failure window did not expire", got.Code)
	}
}

func TestInvalidSuccessResultDoesNotRefundFailureReservation(t *testing.T) {
	general, _ := admitlogin.New(admitlogin.Config{Limit: 4, Window: time.Minute, MaxAccounts: 4})
	failure, _ := failures.New(failures.Config{Limit: 1, Window: time.Minute, Capacity: 4})
	calls := 0
	handler := NewHandlerWithAdmissionAndFailures(loginerFunc(func(context.Context, loginuser.Input) (loginuser.Result, error) {
		calls++
		return loginuser.Result{}, nil
	}), general, failure)
	if got := loginRequest(handler, "synthetic-a", "password", "192.0.2.1:1"); got.Code != 500 {
		t.Fatal(got.Code)
	}
	if got := loginRequest(handler, "synthetic-a", "password", "192.0.2.2:1"); got.Code != 429 || calls != 1 {
		t.Fatal("invalid result refunded the failure reserve")
	}
}
