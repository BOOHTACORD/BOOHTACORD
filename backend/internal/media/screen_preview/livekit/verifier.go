package screenpreviewlivekit

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"time"

	"github.com/google/uuid"
	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
	"voice-platform/backend/internal/media/publish_screen_descriptor"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

const descriptorAttribute = "boohtacord.screen-share.v1"

var (
	ErrUnavailable   = errors.New("screen publication check unavailable")
	ErrNoPublication = screenpreview.ErrNoPublication
)

type Config struct {
	URL, APIKey, APISecret, PreviewRoot string
	HTTPTransport                       http.RoundTripper
}
type Client struct {
	config     Config
	httpClient *http.Client
}

func New(config Config) (Client, error) {
	endpoint, err := url.ParseRequestURI(config.URL)
	if err != nil || endpoint.Host == "" || endpoint.Scheme != "http" && endpoint.Scheme != "https" || config.APIKey == "" || config.APISecret == "" {
		return Client{}, ErrUnavailable
	}
	return Client{config: config, httpClient: &http.Client{Timeout: 3 * time.Second, Transport: config.HTTPTransport}}, nil
}

func (client Client) CurrentTrack(ctx context.Context, channelID, leaseID string) (string, error) {
	if uuid.Validate(channelID) != nil || uuid.Validate(leaseID) != nil {
		return "", ErrUnavailable
	}
	participants, err := client.participants(ctx, channelID)
	if err != nil {
		return "", ErrUnavailable
	}
	expectedIdentity := "voice-lease:" + leaseID
	for _, participant := range participants {
		if participant == nil || participant.GetIdentity() != expectedIdentity {
			continue
		}
		if participant.GetState() != livekit.ParticipantInfo_ACTIVE {
			return "", ErrNoPublication
		}
		var trackSID string
		for _, track := range participant.GetTracks() {
			if track == nil || track.GetMuted() || track.GetType() != livekit.TrackType_VIDEO || track.GetSource() != livekit.TrackSource_SCREEN_SHARE {
				continue
			}
			if track.GetSid() == "" || trackSID != "" {
				return "", ErrNoPublication
			}
			trackSID = track.GetSid()
		}
		if trackSID == "" {
			return "", ErrNoPublication
		}
		return trackSID, nil
	}
	return "", ErrNoPublication
}

func (client Client) CurrentPublication(ctx context.Context, channelID, leaseID, ownerAccountID string) (publish_screen_descriptor.Publication, error) {
	if uuid.Validate(channelID) != nil || uuid.Validate(leaseID) != nil || uuid.Validate(ownerAccountID) != nil {
		return publish_screen_descriptor.Publication{}, ErrUnavailable
	}
	participants, err := client.participants(ctx, channelID)
	if err != nil {
		return publish_screen_descriptor.Publication{}, ErrUnavailable
	}
	expectedIdentity, roomName := "voice-lease:"+leaseID, "voice:"+channelID
	for _, participant := range participants {
		if participant == nil || participant.GetIdentity() != expectedIdentity {
			continue
		}
		if participant.GetState() != livekit.ParticipantInfo_ACTIVE {
			return publish_screen_descriptor.Publication{}, ErrNoPublication
		}
		var trackSID string
		for _, track := range participant.GetTracks() {
			if track == nil || track.GetMuted() || track.GetType() != livekit.TrackType_VIDEO || track.GetSource() != livekit.TrackSource_SCREEN_SHARE {
				continue
			}
			if track.GetSid() == "" || trackSID != "" {
				return publish_screen_descriptor.Publication{}, ErrNoPublication
			}
			trackSID = track.GetSid()
		}
		if trackSID == "" {
			return publish_screen_descriptor.Publication{}, ErrNoPublication
		}
		var descriptor publish_screen_descriptor.Descriptor
		if json.Unmarshal([]byte(participant.GetAttributes()[descriptorAttribute]), &descriptor) != nil || !publish_screen_descriptor.Validate(descriptor) ||
			descriptor.Scope.AccountID != ownerAccountID || descriptor.Scope.RoomID != roomName || descriptor.Scope.OriginID == "" {
			return publish_screen_descriptor.Publication{}, ErrNoPublication
		}
		if descriptor.PublisherState != "publishing" && descriptor.PublisherState != "sharing" && descriptor.PublisherState != "updating" {
			return publish_screen_descriptor.Publication{}, ErrNoPublication
		}
		return publish_screen_descriptor.Publication{TrackSID: trackSID, Scope: descriptor.Scope}, nil
	}
	return publish_screen_descriptor.Publication{}, ErrNoPublication
}

func (client Client) participants(ctx context.Context, channelID string) ([]*livekit.ParticipantInfo, error) {
	roomName := "voice:" + channelID
	token, err := auth.NewAccessToken(client.config.APIKey, client.config.APISecret).
		SetVideoGrant(&auth.VideoGrant{RoomAdmin: true, Room: roomName}).SetValidFor(time.Minute).ToJWT()
	if err != nil {
		return nil, err
	}
	service := livekit.NewRoomServiceJSONClient(client.config.URL, &http.Client{Timeout: 3 * time.Second,
		Transport: bearerTransport{token: token, next: client.httpClient.Transport}})
	response, err := service.ListParticipants(ctx, &livekit.ListParticipantsRequest{Room: roomName})
	if err != nil || response == nil {
		return nil, ErrUnavailable
	}
	return response.GetParticipants(), nil
}

type bearerTransport struct {
	token string
	next  http.RoundTripper
}

func (transport bearerTransport) RoundTrip(request *http.Request) (*http.Response, error) {
	clone := request.Clone(request.Context())
	clone.Header = request.Header.Clone()
	clone.Header.Set("Authorization", "Bearer "+transport.token)
	next := transport.next
	if next == nil {
		next = http.DefaultTransport
	}
	return next.RoundTrip(clone)
}
