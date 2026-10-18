package screenviewerpresence

import (
	"context"
	"errors"
)

var (
	ErrInvalidInput  = errors.New("invalid screen viewer presence request")
	ErrDenied        = errors.New("screen viewer presence access denied")
	ErrUnavailable   = errors.New("screen viewer presence unavailable")
	ErrCapacity      = errors.New("screen viewer presence capacity reached")
	ErrNoPublication = errors.New("current screen publication not found")
)

type Principal struct {
	AccountID     string
	SessionDigest [32]byte
}

type Authority interface {
	AuthorizeOwner(context.Context, Principal, string) (channelID, ownerAccountID string, err error)
	AuthorizeViewer(context.Context, Principal, string, string) (channelID, ownerAccountID, viewerAccountID string, err error)
}

type PublicationVerifier interface {
	CurrentTrack(context.Context, string, string) (string, error)
}

type Store interface {
	Watching(ownerLeaseID, viewerLeaseID, trackSID string) bool
	Watch(ownerLeaseID, ownerAccountID, viewerLeaseID, viewerAccountID, trackSID string) (changed bool, err error)
	Unwatch(ownerLeaseID, viewerLeaseID, trackSID string) bool
	Viewers(ownerLeaseID, trackSID string) []string
	Clear(ownerLeaseID, trackSID string) bool
}

type HintPublisher interface {
	Changed(ownerAccountID string)
}
