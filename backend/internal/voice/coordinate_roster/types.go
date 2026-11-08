package coordinateroster

import (
	"context"
	"errors"
	"time"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

var ErrInvalidConfig = errors.New("invalid voice roster coordinator configuration")
var ErrAdmission = errors.New("voice roster coordinator unavailable")

type Lister interface {
	List(context.Context, string) (roster.Result, error)
}
type Config struct {
	Workers, MaxAccounts, MaxSubscribers, MaxSnapshotBytes int
	PollInterval, ReadTimeout                              time.Duration
}
type State struct {
	Generation  string
	Revision    uint64
	ObservedAt  time.Time
	Unavailable bool
	Roster      roster.Result
}
type job struct {
	account *account
	epoch   uint64
}
type account struct {
	id                              string
	epoch, revision                 uint64
	pending, dirty, have, available bool
	last                            []byte
	state                           State
	subs                            map[*Subscription]struct{}
	cancel                          context.CancelFunc
}
