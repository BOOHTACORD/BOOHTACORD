package joinsound

import (
	"context"
	"github.com/google/uuid"
	"time"
)

type Store interface {
	Reserve(context.Context, string) (bool, error)
	Replace(context.Context, string, Audio) (Sound, error)
	Fetch(context.Context, Actor, string) (Sound, error)
}
type Processor interface {
	Process(context.Context, []byte) (Audio, error)
}
type Service struct {
	store     Store
	processor Processor
}

func New(store Store, processor Processor) Service { return Service{store, processor} }
func validID(id string) bool {
	parsed, err := uuid.Parse(id)
	return err == nil && parsed != uuid.Nil && parsed.String() == id
}
func (s Service) Upload(ctx context.Context, account string, raw []byte) (Sound, error) {
	if !validID(account) || len(raw) == 0 || len(raw) > MaxInput {
		return Sound{}, ErrInvalid
	}
	if s.processor == nil {
		return Sound{}, ErrUnavailable
	}
	ok, err := s.store.Reserve(ctx, account)
	if err != nil {
		return Sound{}, err
	}
	if !ok {
		return Sound{}, ErrRateLimited
	}
	job, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	audio, err := s.processor.Process(job, raw)
	if err != nil {
		return Sound{}, err
	}
	if len(audio.Bytes) == 0 || len(audio.Bytes) > MaxOutput || audio.DurationMS < 300 || audio.DurationMS > 3000 {
		return Sound{}, ErrInvalid
	}
	return s.store.Replace(ctx, account, audio)
}
func (s Service) Download(ctx context.Context, actor Actor, id string) (Sound, error) {
	if !validID(actor.Account) || !validID(id) {
		return Sound{}, ErrNotFound
	}
	return s.store.Fetch(ctx, actor, id)
}
