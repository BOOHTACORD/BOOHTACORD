package joinsound

import "context"

func (s Service) Current(ctx context.Context, a Actor) (Sound, error) {
	if !validID(a.Account) {
		return Sound{}, ErrNotFound
	}
	return s.store.Current(ctx, a)
}
func (s Service) Enable(ctx context.Context, a Actor, enabled bool) (Sound, error) {
	if !validID(a.Account) {
		return Sound{}, ErrNotFound
	}
	return s.store.Enable(ctx, a, enabled)
}
func (s Service) Delete(ctx context.Context, a Actor) error {
	if !validID(a.Account) {
		return ErrNotFound
	}
	return s.store.Delete(ctx, a)
}
