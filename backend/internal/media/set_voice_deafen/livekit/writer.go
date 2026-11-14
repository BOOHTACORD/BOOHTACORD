package setvoicedeafenlivekit

import (
	"context"
	"errors"
	"net/http"
	"net/url"
	"time"

	"github.com/google/uuid"
	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
	setvoicedeafen "voice-platform/backend/internal/media/set_voice_deafen"
)

type Config struct{ URL, APIKey, APISecret string }
type Writer struct{ config Config }

func New(config Config) (Writer, error) {
	endpoint, err := url.ParseRequestURI(config.URL)
	if err != nil || endpoint.Host == "" || (endpoint.Scheme != "http" && endpoint.Scheme != "https") || config.APIKey == "" || config.APISecret == "" {
		return Writer{}, errors.New("invalid LiveKit voice deafen configuration")
	}
	return Writer{config}, nil
}
func (writer Writer) Publish(ctx context.Context, leaseID, channelID string, deafened bool) error {
	if uuid.Validate(leaseID) != nil || uuid.Validate(channelID) != nil {
		return errors.New("invalid voice deafen publication")
	}
	room := "voice:" + channelID
	token, err := auth.NewAccessToken(writer.config.APIKey, writer.config.APISecret).SetVideoGrant(&auth.VideoGrant{RoomAdmin: true, Room: room}).SetValidFor(time.Minute).ToJWT()
	if err != nil {
		return err
	}
	client := livekit.NewRoomServiceJSONClient(writer.config.URL, &http.Client{Timeout: 3 * time.Second, Transport: bearerTransport{token: token, next: http.DefaultTransport}})
	value := "false"
	if deafened {
		value = "true"
	}
	_, err = client.UpdateParticipant(ctx, &livekit.UpdateParticipantRequest{Room: room, Identity: "voice-lease:" + leaseID, Attributes: map[string]string{setvoicedeafen.Attribute: value}})
	return err
}

type bearerTransport struct {
	token string
	next  http.RoundTripper
}

func (transport bearerTransport) RoundTrip(request *http.Request) (*http.Response, error) {
	clone := request.Clone(request.Context())
	clone.Header = request.Header.Clone()
	clone.Header.Set("Authorization", "Bearer "+transport.token)
	return transport.next.RoundTrip(clone)
}
