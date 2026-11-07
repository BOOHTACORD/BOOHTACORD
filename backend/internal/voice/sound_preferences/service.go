package soundpreferences

import (
	"context"
	"errors"
	"fmt"
	"github.com/google/uuid"
)

var ErrConflict = errors.New("voice sound preference revision conflict")

type Snapshot struct {
	Revision int64    `json:"revision"`
	Settings Settings `json:"settings"`
}
type Store interface {
	Read(context.Context, string) (Snapshot, error)
	CompareAndSwap(context.Context, string, int64, Settings) (Snapshot, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func account(value string) (string, error) {
	id, err := uuid.Parse(value)
	if err != nil || id == uuid.Nil {
		return "", errors.New("invalid account")
	}
	return id.String(), nil
}
func (s Service) Read(ctx context.Context, accountID string) (Snapshot, error) {
	id, err := account(accountID)
	if err != nil {
		return Snapshot{}, err
	}
	snapshot, err := s.store.Read(ctx, id)
	if err != nil {
		return Snapshot{}, fmt.Errorf("read voice sound preferences: %w", err)
	}
	return snapshot, nil
}
func (s Service) Save(ctx context.Context, accountID string, revision int64, value Settings) (Snapshot, error) {
	id, err := account(accountID)
	if err != nil {
		return Snapshot{}, err
	}
	if revision < 0 {
		return Snapshot{}, errors.New("invalid revision")
	}
	if err = value.Validate(); err != nil {
		return Snapshot{}, err
	}
	snapshot, err := s.store.CompareAndSwap(ctx, id, revision, value)
	if err != nil {
		return Snapshot{}, fmt.Errorf("save voice sound preferences: %w", err)
	}
	return snapshot, nil
}
