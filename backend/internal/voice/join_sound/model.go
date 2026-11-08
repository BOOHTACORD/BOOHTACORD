package joinsound

import "errors"

const MaxInput = 2 * 1024 * 1024
const MaxOutput = 256 * 1024

var (
	ErrInvalid     = errors.New("invalid join sound")
	ErrNotFound    = errors.New("join sound not available")
	ErrRateLimited = errors.New("join sound upload rate limited")
	ErrUnavailable = errors.New("join sound processor unavailable")
)

type Actor struct {
	Account       string
	SessionDigest [32]byte
}
type Audio struct {
	Bytes      []byte
	DurationMS int
}
type Sound struct {
	ID       string `json:"id"`
	Owner    string `json:"-"`
	Revision int64  `json:"revision"`
	Enabled  bool   `json:"enabled"`
	Audio    Audio  `json:"-"`
}
