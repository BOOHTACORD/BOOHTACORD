package screenpreview

import (
	"context"
	"errors"

	"github.com/google/uuid"
)

func New(authority Authority, publications PublicationVerifier, store Store, capturer Capturer, hints ...HintPublisher) (Service, error) {
	if authority == nil || publications == nil || store == nil || capturer == nil {
		return Service{}, ErrUnavailable
	}
	service := Service{authority: authority, publications: publications, store: store, capturer: capturer}
	if len(hints) > 0 {
		service.hints = hints[0]
	}
	return service, nil
}

func (service Service) Begin(ctx context.Context, principal Principal, leaseID string) (Generation, error) {
	if !validID(leaseID) {
		return Generation{}, ErrInvalidInput
	}
	channelID, err := service.authority.AuthorizeUploader(ctx, principal, leaseID)
	if err != nil {
		return Generation{}, err
	}
	trackSID, err := service.publications.CurrentTrack(ctx, channelID, leaseID)
	if err != nil {
		if errors.Is(err, ErrNoPublication) {
			service.retireCurrent(ctx, leaseID)
		}
		return Generation{}, publicationError(err)
	}

	previousID, previousChannelID, previousTrack, hadPrevious := service.store.Current(leaseID)
	generationID := ""
	if hadPrevious && previousChannelID == channelID && previousTrack == trackSID {
		if err := service.store.Renew(leaseID, previousID); err == nil {
			generationID = previousID
		}
	}
	if generationID == "" {
		generationID, err = service.store.Begin(leaseID, channelID, trackSID)
		if err != nil {
			return Generation{}, err
		}
	}
	if hadPrevious && previousID != generationID {
		_ = service.capturer.Stop(ctx, leaseID, previousID, previousTrack)
		if service.hints != nil {
			service.hints.Invalidated(ctx, leaseID, previousID)
		}
	}
	if err := service.capturer.Ensure(ctx, channelID, leaseID, generationID, trackSID); err != nil {
		_ = service.store.Invalidate(leaseID, generationID)
		_ = service.capturer.Stop(ctx, leaseID, generationID, trackSID)
		return Generation{}, ErrUnavailable
	}
	currentTrackSID, err := service.publications.CurrentTrack(ctx, channelID, leaseID)
	if err != nil || currentTrackSID != trackSID {
		_ = service.store.Invalidate(leaseID, generationID)
		_ = service.capturer.Stop(ctx, leaseID, generationID, trackSID)
		if service.hints != nil {
			service.hints.Invalidated(ctx, leaseID, generationID)
		}
		if err != nil {
			return Generation{}, publicationError(err)
		}
		return Generation{}, ErrStaleGeneration
	}
	// Begin is also the publisher's periodic lease heartbeat. Re-announce an
	// already captured revision so viewers that joined after the prior
	// change-only hint can discover the current frame without waiting for the
	// screen pixels to change.
	if service.hints != nil {
		_, revision, found, readErr := service.store.Read(leaseID, generationID)
		if readErr == nil && found && revision > 0 {
			service.hints.Updated(ctx, leaseID, generationID, revision)
		}
	}
	return Generation{
		SchemaVersion: SchemaVersion, GenerationID: generationID,
		ExpiresAfterSeconds: int(PreviewTTL.Seconds()), MinimumIntervalSeconds: int(CaptureInterval.Seconds()),
	}, nil
}

func (service Service) retireCurrent(ctx context.Context, leaseID string) {
	generationID, channelID, trackSID, found := service.store.Current(leaseID)
	if !found {
		return
	}
	service.retire(ctx, ActiveGeneration{LeaseID: leaseID, GenerationID: generationID, ChannelID: channelID, TrackSID: trackSID})
}

// Upload is retained as a compatibility route for older clients. Frames are now
// captured by LiveKit Egress and never accepted from a client request body.
func (Service) Upload(context.Context, Principal, string, string, uint64, []byte) error {
	return ErrServerManaged
}

func (service Service) Invalidate(ctx context.Context, principal Principal, leaseID, generationID string) error {
	if !validID(leaseID) || !validID(generationID) {
		return ErrInvalidInput
	}
	if _, err := service.authority.AuthorizeUploader(ctx, principal, leaseID); err != nil {
		return err
	}
	trackSID, err := service.store.Track(leaseID, generationID)
	if err != nil {
		return err
	}
	if err := service.store.Invalidate(leaseID, generationID); err != nil {
		return err
	}
	stopErr := service.capturer.Stop(ctx, leaseID, generationID, trackSID)
	if service.hints != nil {
		service.hints.Invalidated(ctx, leaseID, generationID)
	}
	if stopErr != nil {
		return ErrUnavailable
	}
	return nil
}

func validID(value string) bool { return uuid.Validate(value) == nil }

func publicationError(err error) error {
	if errors.Is(err, ErrNoPublication) {
		return ErrNotFound
	}
	return ErrUnavailable
}
