package completepasswordreset

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"

	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/registration"
	"voice-platform/backend/internal/identity/session"
)

var (
	ErrResetNotFound    = errors.New("password reset not found")
	ErrInvalidOrExpired = errors.New("invalid or expired password reset")
)

type Input struct {
	Token    string
	Password string
}

type Store interface {
	// Preflight only checks current eligibility; Consume must recheck atomically.
	Preflight(context.Context, [sha256.Size]byte) error
	Consume(context.Context, [sha256.Size]byte, string) error
}

type Service struct {
	store Store
}

func New(store Store) Service {
	return Service{store: store}
}

func (service Service) Complete(ctx context.Context, input Input) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	digest, err := session.Digest(input.Token)
	if err != nil {
		return ErrInvalidOrExpired
	}
	if err := registration.ValidatePassword(input.Password); err != nil {
		return ErrInvalidOrExpired
	}
	if err := service.store.Preflight(ctx, digest); err != nil {
		if errors.Is(err, ErrResetNotFound) {
			return ErrInvalidOrExpired
		}
		return fmt.Errorf("preflight password reset: %w", err)
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	passwordHash, err := password.Hash(ctx, input.Password)
	if err != nil {
		return fmt.Errorf("hash reset password: %w", err)
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	if err := service.store.Consume(ctx, digest, passwordHash); err != nil {
		if errors.Is(err, ErrResetNotFound) {
			return ErrInvalidOrExpired
		}
		return fmt.Errorf("consume password reset: %w", err)
	}
	return nil
}
