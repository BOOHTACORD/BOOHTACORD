package screenpreview

import (
	"context"
	"errors"
	"time"
)

const (
	SchemaVersion                 = 1
	PreviewTTL                    = 90 * time.Second
	UploadInterval                = 4 * time.Second
	CaptureInterval               = 30 * time.Second
	CapturePollInterval           = time.Second
	CaptureReconcileRetryInterval = 5 * time.Second
)

var (
	ErrInvalidInput    = errors.New("invalid screen preview request")
	ErrDenied          = errors.New("screen preview access denied")
	ErrUnavailable     = errors.New("screen preview unavailable")
	ErrNoPublication   = errors.New("current screen publication not found")
	ErrNotFound        = errors.New("screen preview not found")
	ErrNoUpdate        = errors.New("screen preview has no newer revision")
	ErrRateLimited     = errors.New("screen preview rate limited")
	ErrCapacity        = errors.New("screen preview capacity reached")
	ErrStaleGeneration = errors.New("screen preview generation superseded")
	ErrServerManaged   = errors.New("screen preview frames are captured by the server")
)

type Principal struct {
	AccountID     string
	SessionDigest [32]byte
}
type Authority interface {
	AuthorizeUploader(context.Context, Principal, string) (string, error)
	AuthorizeViewer(context.Context, Principal, string) (string, error)
}
type PublicationVerifier interface {
	CurrentTrack(context.Context, string, string) (string, error)
}
type Capturer interface {
	Ensure(context.Context, string, string, string, string) error
	Stop(context.Context, string, string, string) error
	Latest(context.Context, string, string) (CaptureFrame, error)
	Active() []CaptureSession
}
type CaptureFrame struct {
	Fingerprint string
	JPEG        []byte
}
type CaptureSession struct {
	LeaseID, GenerationID string
}
type Store interface {
	Begin(string, string, string) (string, error)
	Current(string) (string, string, string, bool)
	Renew(string, string) error
	Active() []ActiveGeneration
	Capture(string, string, string, []byte) (uint64, bool, error)
	Track(string, string) (string, error)
	Reserve(string, string, uint64) (string, error)
	Commit(string, string, uint64, []byte) error
	Read(string, string) ([]byte, uint64, bool, error)
	Invalidate(string, string) error
}
type ActiveGeneration struct {
	LeaseID, GenerationID, ChannelID, TrackSID string
}
type HintPublisher interface {
	Updated(context.Context, string, string, uint64)
	Invalidated(context.Context, string, string)
}
type Service struct {
	authority    Authority
	publications PublicationVerifier
	store        Store
	capturer     Capturer
	hints        HintPublisher
}
type Generation struct {
	SchemaVersion          int    `json:"schema_version"`
	GenerationID           string `json:"generation_id"`
	ExpiresAfterSeconds    int    `json:"expires_after_seconds"`
	MinimumIntervalSeconds int    `json:"minimum_interval_seconds"`
}
type Preview struct {
	JPEG     []byte
	Revision uint64
}
