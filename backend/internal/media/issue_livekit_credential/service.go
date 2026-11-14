package issuelivekitcredential

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	flowstage "voice-platform/backend/internal/observability/flow_stage"

	livekitcredential "voice-platform/backend/internal/media/livekit_credential"
)

var (
	ErrInvalidInput     = errors.New("invalid livekit credential input")
	ErrLeaseUnavailable = errors.New("voice lease unavailable")
)

type Input struct {
	ActorID, LeaseID string
	SessionDigest    [sha256.Size]byte
}
type Lease struct {
	ID, ChannelID, DisplayName, JoinSoundID, JoinSoundRevision string
	MicrophoneAllowed                                          bool
}
type Store interface {
	FindActive(context.Context, Input) (Lease, error)
}
type Issuer interface {
	Issue(string, string, string, string) (livekitcredential.Credential, error)
}
type Service struct {
	store  Store
	issuer Issuer
}

func New(store Store, issuer Issuer) Service { return Service{store: store, issuer: issuer} }
func (service Service) Issue(context context.Context, input Input) (result livekitcredential.Credential, err error) {
	context, span := flowstage.Begin(context, "voice.credential.server", "credential")
	defer func() {
		flowstage.End(span, err, flowstage.Reject(ErrInvalidInput, "invalid"), flowstage.Reject(ErrLeaseUnavailable, "permission_denied"))
	}()
	if input.ActorID == "" || input.LeaseID == "" || input.SessionDigest == [sha256.Size]byte{} {
		return livekitcredential.Credential{}, ErrInvalidInput
	}
	lease, err := service.store.FindActive(context, input)
	if errors.Is(err, ErrLeaseUnavailable) {
		return livekitcredential.Credential{}, ErrLeaseUnavailable
	}
	if err != nil {
		return livekitcredential.Credential{}, fmt.Errorf("find active voice lease: %w", err)
	}
	var credential livekitcredential.Credential
	var issuedErr error
	if issuer, ok := service.issuer.(interface {
		IssueWithSoundAndMicrophonePolicy(string, string, string, string, string, string, bool) (livekitcredential.Credential, error)
	}); ok && lease.JoinSoundID != "" {
		credential, issuedErr = issuer.IssueWithSoundAndMicrophonePolicy(lease.ID, lease.ChannelID, input.ActorID, lease.DisplayName, lease.JoinSoundID, lease.JoinSoundRevision, lease.MicrophoneAllowed)
	} else if issuer, ok := service.issuer.(interface {
		IssueWithMicrophonePolicy(string, string, string, string, bool) (livekitcredential.Credential, error)
	}); ok {
		credential, issuedErr = issuer.IssueWithMicrophonePolicy(lease.ID, lease.ChannelID, input.ActorID, lease.DisplayName, lease.MicrophoneAllowed)
	} else if issuer, ok := service.issuer.(interface {
		IssueWithSound(string, string, string, string, string, string) (livekitcredential.Credential, error)
	}); ok && lease.JoinSoundID != "" {
		credential, issuedErr = issuer.IssueWithSound(lease.ID, lease.ChannelID, input.ActorID, lease.DisplayName, lease.JoinSoundID, lease.JoinSoundRevision)
	} else {
		credential, issuedErr = service.issuer.Issue(lease.ID, lease.ChannelID, input.ActorID, lease.DisplayName)
	}
	if issuedErr != nil {
		return livekitcredential.Credential{}, fmt.Errorf("issue livekit credential: %w", issuedErr)
	}
	return credential, nil
}
