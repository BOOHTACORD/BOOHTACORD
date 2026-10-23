package loginapi

import (
	"context"
	"errors"
	"time"

	admitlogin "voice-platform/backend/internal/identity/admit_login"
	loginuser "voice-platform/backend/internal/identity/login_user"
	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/registration"
)

func admittedLogin(ctx context.Context, input loginuser.Input, loginer Loginer, budget *admitlogin.Budget) (loginuser.Result, time.Duration, error) {
	normalized, err := registration.NormalizeLogin(input.Login)
	if err != nil {
		return loginuser.Result{}, 0, loginuser.ErrInvalidCredentials
	}
	if err := ctx.Err(); err != nil {
		return loginuser.Result{}, 0, err
	}
	input.Login = normalized
	var permit *admitlogin.Reservation
	if budget != nil {
		var retry time.Duration
		permit, retry, err = budget.Reserve(ctx, normalized)
		if err != nil {
			return loginuser.Result{}, retry, err
		}
	}
	outcome := admitlogin.Infrastructure
	defer func() { permit.Complete(outcome) }()
	if err := ctx.Err(); err != nil {
		outcome = admitlogin.NotStarted
		return loginuser.Result{}, 0, err
	}
	result, err := loginer.Login(ctx, input)
	switch {
	case err == nil:
		outcome = admitlogin.Success
	case errors.Is(err, password.ErrBusy):
		outcome = admitlogin.NotStarted
	case errors.Is(err, loginuser.ErrInvalidCredentials):
		outcome = admitlogin.Invalid
	case errors.Is(err, loginuser.ErrBlocked):
		outcome = admitlogin.Blocked
	case errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded):
		outcome = admitlogin.Cancelled
	}
	return result, 0, err
}
