package changeownpassword

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"

	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/registration"
)

var (
	ErrInvalidInput           = errors.New("invalid password change input")
	ErrCurrentPasswordInvalid = errors.New("current password is invalid")
	ErrCredentialChanged      = errors.New("account credentials changed")
)

type Input struct {
	AccountID            string
	CurrentPassword      string
	NewPassword          string
	CurrentSessionDigest [sha256.Size]byte
}

type Store interface {
	FindPasswordHash(context.Context, string) (string, error)
	ChangePassword(context.Context, string, string, string, [sha256.Size]byte) error
}

type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Change(ctx context.Context, input Input) error {
	if input.AccountID == "" || input.CurrentSessionDigest == [sha256.Size]byte{} || registration.ValidatePassword(input.CurrentPassword) != nil || registration.ValidatePassword(input.NewPassword) != nil {
		return ErrInvalidInput
	}
	currentHash, err := service.store.FindPasswordHash(ctx, input.AccountID)
	if err != nil {
		return fmt.Errorf("find password hash: %w", err)
	}
	valid, err := password.Verify(ctx, input.CurrentPassword, currentHash)
	if err != nil {
		return fmt.Errorf("verify current password: %w", err)
	}
	if !valid {
		return ErrCurrentPasswordInvalid
	}
	newHash, err := password.Hash(ctx, input.NewPassword)
	if err != nil {
		return fmt.Errorf("hash new password: %w", err)
	}
	if err := service.store.ChangePassword(ctx, input.AccountID, currentHash, newHash, input.CurrentSessionDigest); err != nil {
		return fmt.Errorf("change password: %w", err)
	}
	return nil
}
