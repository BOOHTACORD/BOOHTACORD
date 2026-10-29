package screenpreviewlivekit

import (
	"context"
	"errors"
	"net/http"
	"net/url"
	"time"

	"github.com/google/uuid"
	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

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
	roomName := "voice:" + channelID
	token, err := auth.NewAccessToken(client.config.APIKey, client.config.APISecret).
		SetVideoGrant(&auth.VideoGrant{RoomAdmin: true, Room: roomName}).SetValidFor(time.Minute).ToJWT()
	if err != nil {
		return "", ErrUnavailable
	}
	service := livekit.NewRoomServiceJSONClient(client.config.URL, &http.Client{Timeout: 3 * time.Second,
		Transport: bearerTransport{token: token, next: client.httpClient.Transport}})
	response, err := service.ListParticipants(ctx, &livekit.ListParticipantsRequest{Room: roomName})
	if err != nil || response == nil {
		return "", ErrUnavailable
	}
	expectedIdentity := "voice-lease:" + leaseID
	for _, participant := range response.GetParticipants() {
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
