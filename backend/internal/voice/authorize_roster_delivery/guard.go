// Package authorizerosterdelivery rechecks private roster delivery boundaries.
package authorizerosterdelivery

import (
	"context"
	"crypto/subtle"
	"errors"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

var ErrSession = errors.New("roster delivery session invalid")
var ErrStale = errors.New("roster delivery requires refresh")
var ErrUnavailable = errors.New("roster delivery temporarily unavailable")

type Guard struct {
	auth       sessionapi.Authenticator
	repository roster.Repository
	delivery   transactionDelivery
}

func New(authenticator sessionapi.Authenticator, repository roster.Repository, deliveries ...transactionDelivery) Guard {
	var delivery transactionDelivery
	if len(deliveries) > 0 {
		delivery = deliveries[0]
	}
	return Guard{auth: authenticator, repository: repository, delivery: delivery}
}

// Check must be called for each recipient immediately before its socket write.
// The caller owns a deadline and must not log token or internal proof.
func (g Guard) Check(ctx context.Context, token string, expected auth.Principal, snapshot roster.Result) error {
	if g.auth == nil || g.repository == nil {
		return ErrUnavailable
	}
	if token == "" || expected.AccountID == "" {
		return ErrSession
	}
	if err := g.session(ctx, token, expected); err != nil {
		return err
	}
	visible, err := g.repository.ListVisible(ctx, expected.AccountID)
	if err != nil || ctx.Err() != nil {
		return ErrUnavailable
	}
	if !matches(snapshot, visible) {
		return ErrStale
	}
	return g.session(ctx, token, expected)
}

func (g Guard) session(ctx context.Context, token string, expected auth.Principal) error {
	current, err := g.auth.Authenticate(ctx, token)
	if ctx.Err() != nil {
		return ErrUnavailable
	}
	if errors.Is(err, auth.ErrUnauthenticated) {
		return ErrSession
	}
	if err != nil {
		return ErrUnavailable
	}
	if current.AccountID != expected.AccountID || subtle.ConstantTimeCompare(current.SessionDigest[:], expected.SessionDigest[:]) != 1 {
		return ErrSession
	}
	return nil
}
