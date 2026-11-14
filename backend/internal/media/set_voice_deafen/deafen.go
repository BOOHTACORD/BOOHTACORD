package setvoicedeafen

import (
	"context"
	"errors"

	"github.com/google/uuid"
)

const Attribute = "boohtacord.voice.deafened.v1"

var (
	ErrInvalid     = errors.New("invalid voice deafen update")
	ErrDenied      = errors.New("voice deafen update denied")
	ErrUnavailable = errors.New("voice deafen update unavailable")
)

type Principal struct {
	AccountID     string
	SessionDigest [32]byte
}
type Repository interface {
	Apply(context.Context, Principal, string, bool) error
}
type Service struct{ repository Repository }

func New(repository Repository) Service { return Service{repository: repository} }
func (service Service) Apply(ctx context.Context, principal Principal, leaseID string, deafened bool) error {
	if uuid.Validate(principal.AccountID) != nil || uuid.Validate(leaseID) != nil {
		return ErrInvalid
	}
	return service.repository.Apply(ctx, principal, leaseID, deafened)
}
