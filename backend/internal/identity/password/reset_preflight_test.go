package password_test

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
	resetapi "voice-platform/backend/internal/identity/complete_password_reset/api"

	reset "voice-platform/backend/internal/identity/complete_password_reset"
	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/session"
)

type preflightResetStore struct {
	checks, consumes     int
	checkErr, consumeErr error
	afterCheck           func()
}

func (store *preflightResetStore) Preflight(ctx context.Context, _ [sha256.Size]byte) error {
	store.checks++
	if store.afterCheck != nil {
		store.afterCheck()
	}
	if store.checkErr != nil {
		return store.checkErr
	}
	return nil
}
func (store *preflightResetStore) Consume(ctx context.Context, _ [sha256.Size]byte, _ string) error {
	store.consumes++
	if store.consumeErr != nil {
		return store.consumeErr
	}
	return ctx.Err()
}

func TestInvalidResetPreflightDoesNotDeriveOrConsume(t *testing.T) {
	issued, err := session.Issue()
	if err != nil {
		t.Fatal("cannot prepare synthetic token")
	}
	for _, kind := range []string{"unknown", "expired", "used"} {
		t.Run(kind, func(t *testing.T) {
			store := &preflightResetStore{checkErr: reset.ErrResetNotFound, consumeErr: reset.ErrResetNotFound}
			count := password.CountDerivationsForTest(t)
			err := reset.New(store).Complete(context.Background(), reset.Input{Token: issued.Token, Password: "synthetic replacement password"})
			if !errors.Is(err, reset.ErrInvalidOrExpired) || count() != 0 || store.checks != 1 || store.consumes != 0 {
				t.Fatalf("invalid preflight: rejected=%v KDF=%d checks=%d consumes=%d; want true/0/1/0", errors.Is(err, reset.ErrInvalidOrExpired), count(), store.checks, store.consumes)
			}
		})
	}
}

func TestResetPreflightFailureAndCancellationStopBeforeKDF(t *testing.T) {
	issued, err := session.Issue()
	if err != nil {
		t.Fatal("cannot prepare synthetic token")
	}
	failure := errors.New("synthetic database unavailable")
	for _, kind := range []string{"database failure", "cancelled before", "deadline before", "cancelled after read", "malformed token", "invalid password"} {
		t.Run(kind, func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			store := &preflightResetStore{}
			input := reset.Input{Token: issued.Token, Password: "synthetic replacement password"}
			expected, checks := error(failure), 1
			switch kind {
			case "database failure":
				store.checkErr = failure
			case "cancelled before":
				cancel()
				expected = context.Canceled
				checks = 0
			case "deadline before":
				expired, stop := context.WithDeadline(context.Background(), time.Unix(1, 0))
				defer stop()
				ctx = expired
				expected = context.DeadlineExceeded
				checks = 0
			case "cancelled after read":
				store.afterCheck = cancel
				expected = context.Canceled
			case "malformed token":
				input.Token = "malformed"
				expected = reset.ErrInvalidOrExpired
				checks = 0
			case "invalid password":
				input.Password = "short"
				expected = reset.ErrInvalidOrExpired
				checks = 0
			}
			count := password.CountDerivationsForTest(t)
			err := reset.New(store).Complete(ctx, input)
			if !errors.Is(err, expected) || count() != 0 || store.checks != checks || store.consumes != 0 {
				t.Fatalf("preflight boundary: expected_error=%v KDF=%d checks=%d consumes=%d", errors.Is(err, expected), count(), store.checks, store.consumes)
			}
		})
	}
}

// Cancellation becomes observable on the first Err call after Hash returned.
// The real context's Done channel closes at that same boundary. Argon2 itself
// still runs natively; no production hook or fake cryptography is introduced.
type cancelAfterHashContext struct {
	context.Context
	deriveCount func() int64
	cancel      context.CancelFunc
	afterWork   int
}

func (ctx *cancelAfterHashContext) Err() error {
	if ctx.deriveCount() > 0 {
		ctx.afterWork++
		if ctx.afterWork == 2 {
			ctx.cancel()
		}
	}
	return ctx.Context.Err()
}
func TestResetCancellationAfterHashDoesNotStartConsume(t *testing.T) {
	issued, err := session.Issue()
	if err != nil {
		t.Fatal("cannot prepare synthetic token")
	}
	count := password.CountDerivationsForTest(t)
	base, cancel := context.WithCancel(context.Background())
	defer cancel()
	ctx := &cancelAfterHashContext{Context: base, deriveCount: count, cancel: cancel}
	store := &preflightResetStore{}
	err = reset.New(store).Complete(ctx, reset.Input{Token: issued.Token, Password: "synthetic replacement password"})
	if !errors.Is(err, context.Canceled) || count() != 1 || store.checks != 1 || store.consumes != 0 {
		t.Fatal("post-hash cancellation started a mutation or skipped native KDF")
	}
}

func TestInvalidResetStillRejectsBeforeSaturatedKDF(t *testing.T) {
	issued, err := session.Issue()
	if err != nil {
		t.Fatal("cannot prepare synthetic token")
	}
	password.SaturateForTest(t)
	count := password.CountDerivationsForTest(t)
	store := &preflightResetStore{checkErr: reset.ErrResetNotFound}
	handler := resetapi.NewHandler(reset.New(store))
	encoded, _ := json.Marshal(map[string]string{"token": issued.Token, "password": "synthetic replacement password"})
	req := httptest.NewRequest("POST", "/api/v1/auth/password-reset/complete", strings.NewReader(string(encoded)))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, req)
	if response.Code != 400 || !strings.Contains(response.Body.String(), `"VALIDATION_FAILED"`) || strings.Contains(response.Body.String(), issued.Token) || count() != 0 || store.consumes != 0 || len(response.Result().Cookies()) != 0 {
		t.Fatal("invalid reset must keep generic 400 without entering full KDF gate")
	}
}
