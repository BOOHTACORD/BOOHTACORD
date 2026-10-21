package authenticatesession

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"time"

	"voice-platform/backend/internal/identity/session"
)

var (
	ErrUnauthenticated = errors.New("unauthenticated")
	ErrSessionNotFound = errors.New("active session not found")
)

type Principal struct {
	AccountID     string
	Role          string
	DisplayName   string
	SessionDigest [sha256.Size]byte
	ExpiresAt     time.Time
}

type Sessions interface {
	FindActive(context.Context, [sha256.Size]byte) (Principal, error)
}

// SessionLookupTimeout reuses the five-second roster snapshot/revalidation budget.
// It bounds only the database lookup, not the lifetime of an authenticated SSE request.
const SessionLookupTimeout = 5 * time.Second

type Service struct {
	sessions Sessions
}

func New(sessions Sessions) Service {
	return Service{sessions: sessions}
}

func (service Service) Authenticate(ctx context.Context, token string) (Principal, error) {
	digest, err := session.Digest(token)
	if err != nil {
		return Principal{}, ErrUnauthenticated
	}
	lookup, cancel := context.WithTimeout(ctx, SessionLookupTimeout)
	defer cancel()
	principal, err := service.sessions.FindActive(lookup, digest)
	if errors.Is(err, ErrSessionNotFound) {
		return Principal{}, ErrUnauthenticated
	}
	if err != nil {
		return Principal{}, fmt.Errorf("find active session: %w", err)
	}
	principal.SessionDigest = digest
	return principal, nil
}
