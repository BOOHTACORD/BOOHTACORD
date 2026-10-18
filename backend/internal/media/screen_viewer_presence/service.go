package screenviewerpresence

import (
	"context"
	"errors"
	"regexp"

	"github.com/google/uuid"
)

const maxTrackSIDLength = 128

var validTrackSID = regexp.MustCompile(`^[A-Za-z0-9_-]{1,128}$`)

type Service struct {
	authority    Authority
	publications PublicationVerifier
	store        Store
	hints        HintPublisher
}

func New(authority Authority, publications PublicationVerifier, store Store, hints HintPublisher) (Service, error) {
	if authority == nil || publications == nil || store == nil {
		return Service{}, ErrUnavailable
	}
	return Service{authority: authority, publications: publications, store: store, hints: hints}, nil
}

func (service Service) Watch(ctx context.Context, principal Principal, viewerLeaseID, ownerLeaseID, trackSID string) error {
	if !validLeaseID(viewerLeaseID) || !validLeaseID(ownerLeaseID) || !validTrackSID.MatchString(trackSID) {
		return ErrInvalidInput
	}
	channelID, ownerAccountID, viewerAccountID, err := service.authority.AuthorizeViewer(ctx, principal, viewerLeaseID, ownerLeaseID)
	if err != nil {
		return authorizationError(err)
	}
	if !service.store.Watching(ownerLeaseID, viewerLeaseID, trackSID) {
		current, verifyErr := service.publications.CurrentTrack(ctx, channelID, ownerLeaseID)
		if errors.Is(verifyErr, ErrNoPublication) || verifyErr == nil && current != trackSID {
			return ErrDenied
		}
		if verifyErr != nil {
			return ErrUnavailable
		}
	}
	changed, err := service.store.Watch(ownerLeaseID, ownerAccountID, viewerLeaseID, viewerAccountID, trackSID)
	if errors.Is(err, ErrCapacity) {
		return err
	}
	if err != nil {
		return ErrUnavailable
	}
	if changed {
		service.changed(ownerAccountID)
	}
	return nil
}

func (service Service) StopWatching(ctx context.Context, principal Principal, viewerLeaseID, ownerLeaseID, trackSID string) error {
	if !validLeaseID(viewerLeaseID) || !validLeaseID(ownerLeaseID) || !validTrackSID.MatchString(trackSID) {
		return ErrInvalidInput
	}
	_, ownerAccountID, _, err := service.authority.AuthorizeViewer(ctx, principal, viewerLeaseID, ownerLeaseID)
	if err != nil {
		return authorizationError(err)
	}
	if service.store.Unwatch(ownerLeaseID, viewerLeaseID, trackSID) {
		service.changed(ownerAccountID)
	}
	return nil
}

func (service Service) Viewers(ctx context.Context, principal Principal, ownerLeaseID string) ([]string, error) {
	if !validLeaseID(ownerLeaseID) {
		return nil, ErrInvalidInput
	}
	channelID, ownerAccountID, err := service.authority.AuthorizeOwner(ctx, principal, ownerLeaseID)
	if err != nil {
		return nil, authorizationError(err)
	}
	trackSID, err := service.publications.CurrentTrack(ctx, channelID, ownerLeaseID)
	if errors.Is(err, ErrNoPublication) {
		if service.store.Clear(ownerLeaseID, "") {
			service.changed(ownerAccountID)
		}
		return []string{}, nil
	}
	if err != nil {
		return nil, ErrUnavailable
	}
	return service.store.Viewers(ownerLeaseID, trackSID), nil
}

func (service Service) ClearOwner(ctx context.Context, principal Principal, ownerLeaseID, trackSID string) error {
	if !validLeaseID(ownerLeaseID) || trackSID != "" && !validTrackSID.MatchString(trackSID) {
		return ErrInvalidInput
	}
	_, ownerAccountID, err := service.authority.AuthorizeOwner(ctx, principal, ownerLeaseID)
	if err != nil {
		return authorizationError(err)
	}
	if service.store.Clear(ownerLeaseID, trackSID) {
		service.changed(ownerAccountID)
	}
	return nil
}

func (service Service) changed(ownerAccountID string) {
	if service.hints != nil && ownerAccountID != "" {
		service.hints.Changed(ownerAccountID)
	}
}

func validLeaseID(value string) bool { return uuid.Validate(value) == nil }

func authorizationError(err error) error {
	if errors.Is(err, ErrDenied) {
		return ErrDenied
	}
	return ErrUnavailable
}
