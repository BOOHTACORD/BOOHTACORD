package loginuser

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"time"

	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/registration"
	"voice-platform/backend/internal/identity/session"
	correlatesession "voice-platform/backend/internal/observability/correlate_session"
	flowstage "voice-platform/backend/internal/observability/flow_stage"
)

var (
	ErrAccountNotFound    = errors.New("account not found")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrBlocked            = errors.New("account is blocked")
)

type Input struct {
	Login    string
	Password string
}

type Account struct {
	ID           string
	Login        string
	PasswordHash string
	Blocked      bool
}

type Accounts interface {
	FindByLogin(context.Context, string) (Account, error)
}

type Sessions interface {
	Create(context.Context, string, [sha256.Size]byte, time.Time) error
}

type Result struct {
	Token     string
	ExpiresAt time.Time
}

type Service struct {
	accounts Accounts
	sessions Sessions
}

func New(accounts Accounts, sessions Sessions) Service {
	return Service{accounts: accounts, sessions: sessions}
}

func (service Service) Login(context context.Context, input Input) (result Result, err error) {
	context, span := flowstage.Begin(context, "auth.login.server", "authenticate")
	defer func() {
		flowstage.End(span, err, flowstage.Reject(ErrInvalidCredentials, "permission_denied"), flowstage.Reject(ErrBlocked, "permission_denied"))
	}()
	login, err := registration.NormalizeLogin(input.Login)
	if err != nil {
		return Result{}, ErrInvalidCredentials
	}
	account, err := service.accounts.FindByLogin(context, login)
	if errors.Is(err, ErrAccountNotFound) {
		password.VerifyUnknown(input.Password)
		return Result{}, ErrInvalidCredentials
	}
	if err != nil {
		return Result{}, fmt.Errorf("find account: %w", err)
	}
	valid, err := password.Verify(input.Password, account.PasswordHash)
	if err != nil {
		return Result{}, fmt.Errorf("verify password hash: %w", err)
	}
	if !valid {
		return Result{}, ErrInvalidCredentials
	}
	if account.Blocked {
		return Result{}, ErrBlocked
	}
	issued, err := session.Issue()
	if err != nil {
		return Result{}, fmt.Errorf("issue session: %w", err)
	}
	expiresAt := time.Now().Add(session.AbsoluteLifetime)
	if err := service.sessions.Create(context, account.ID, issued.Digest, expiresAt); err != nil {
		return Result{}, fmt.Errorf("persist session: %w", err)
	}
	span.SetAttributes(correlatesession.Attributes(account.ID, issued.Digest)...)
	flowstage.Mark(context, "commit", "success")
	return Result{Token: issued.Token, ExpiresAt: expiresAt}, nil
}
