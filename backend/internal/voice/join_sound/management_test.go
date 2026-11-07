package joinsound

import "context"

func (s *storeFake) Current(context.Context, Actor) (Sound, error) { return s.value, nil }
func (s *storeFake) Enable(_ context.Context, _ Actor, enabled bool) (Sound, error) {
	s.value.Enabled = enabled
	return s.value, nil
}
func (s *storeFake) Delete(context.Context, Actor) error { s.value = Sound{}; return nil }
