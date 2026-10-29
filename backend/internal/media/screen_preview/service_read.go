package screenpreview

import (
	"context"
	"errors"
)

func (service Service) Read(ctx context.Context, principal Principal, leaseID, generationID string, after uint64) (Preview, error) {
	if !validID(leaseID) || !validID(generationID) {
		return Preview{}, ErrInvalidInput
	}
	channelID, err := service.authority.AuthorizeViewer(ctx, principal, leaseID)
	if err != nil {
		return Preview{}, err
	}
	trackSID, err := service.store.Track(leaseID, generationID)
	if err != nil {
		return Preview{}, ErrNotFound
	}
	currentSID, err := service.publications.CurrentTrack(ctx, channelID, leaseID)
	if err != nil {
		if errors.Is(err, ErrNoPublication) {
			service.retire(ctx, ActiveGeneration{LeaseID: leaseID, GenerationID: generationID, ChannelID: channelID, TrackSID: trackSID})
			return Preview{}, ErrNotFound
		}
		return Preview{}, ErrUnavailable
	}
	if currentSID != trackSID {
		service.retire(ctx, ActiveGeneration{LeaseID: leaseID, GenerationID: generationID, ChannelID: channelID, TrackSID: trackSID})
		return Preview{}, ErrNotFound
	}
	body, revision, found, err := service.store.Read(leaseID, generationID)
	if err != nil {
		return Preview{}, err
	}
	if !found {
		return Preview{}, ErrNoUpdate
	}
	if revision <= after {
		return Preview{Revision: revision}, ErrNoUpdate
	}
	return Preview{JPEG: body, Revision: revision}, nil
}
