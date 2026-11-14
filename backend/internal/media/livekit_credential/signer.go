package livekitcredential

import (
	"errors"
	"fmt"
	"net/url"
	"time"

	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
)

const validity = time.Minute

var ErrInvalidConfig = errors.New("invalid livekit credential configuration")

type Config struct{ URL, APIKey, APISecret string }
type Credential struct {
	URL, Token, LeaseID string
	ExpiresAt           time.Time
	MicrophoneAllowed   bool
}
type Signer struct {
	config Config
	now    func() time.Time
}

func New(config Config) (Signer, error) {
	endpoint, err := url.ParseRequestURI(config.URL)
	if err != nil || endpoint.Host == "" || (endpoint.Scheme != "ws" && endpoint.Scheme != "wss") || config.APIKey == "" || config.APISecret == "" {
		return Signer{}, ErrInvalidConfig
	}
	return Signer{config: config, now: time.Now}, nil
}

func (signer Signer) Issue(leaseID, channelID, accountID, displayName string) (Credential, error) {
	return signer.issue(leaseID, channelID, accountID, displayName, nil, true)
}
func (signer Signer) IssueWithSound(leaseID, channelID, accountID, displayName, id, revision string) (Credential, error) {
	return signer.issue(leaseID, channelID, accountID, displayName, map[string]string{"boohtacord.join_sound_id": id, "boohtacord.join_sound_revision": revision}, true)
}
func (signer Signer) IssueWithMicrophonePolicy(leaseID, channelID, accountID, displayName string, microphoneAllowed bool) (Credential, error) {
	return signer.issue(leaseID, channelID, accountID, displayName, nil, microphoneAllowed)
}
func (signer Signer) IssueWithSoundAndMicrophonePolicy(leaseID, channelID, accountID, displayName, id, revision string, microphoneAllowed bool) (Credential, error) {
	return signer.issue(leaseID, channelID, accountID, displayName, map[string]string{"boohtacord.join_sound_id": id, "boohtacord.join_sound_revision": revision}, microphoneAllowed)
}
func (signer Signer) issue(leaseID, channelID, accountID, displayName string, attributes map[string]string, microphoneAllowed bool) (Credential, error) {
	if leaseID == "" || channelID == "" || accountID == "" || displayName == "" {
		return Credential{}, ErrInvalidConfig
	}
	grant := &auth.VideoGrant{RoomJoin: true, RoomCreate: true, Room: "voice:" + channelID}
	grant.SetCanPublish(true)
	grant.SetCanSubscribe(true)
	grant.SetCanPublishData(false)
	sources := []livekit.TrackSource{livekit.TrackSource_SCREEN_SHARE, livekit.TrackSource_SCREEN_SHARE_AUDIO}
	if microphoneAllowed {
		sources = append([]livekit.TrackSource{livekit.TrackSource_MICROPHONE}, sources...)
	}
	grant.SetCanPublishSources(sources)
	token, err := auth.NewAccessToken(signer.config.APIKey, signer.config.APISecret).
		SetIdentity("voice-lease:" + leaseID).
		SetName(displayName).
		SetMetadata("account:" + accountID).
		SetAttributes(attributes).
		SetVideoGrant(grant).
		SetValidFor(validity).
		ToJWT()
	if err != nil {
		return Credential{}, fmt.Errorf("sign livekit credential: %w", err)
	}
	return Credential{URL: signer.config.URL, Token: token, LeaseID: leaseID, ExpiresAt: signer.now().Add(validity), MicrophoneAllowed: microphoneAllowed}, nil
}
