package preferences

import "context"

type fakeStore struct {
	settings Settings
	input    Input
	err      error
	called   bool
}

func (store *fakeStore) Read(_ context.Context, accountID string) (Settings, error) {
	store.called = true
	if store.err != nil {
		return Settings{}, store.err
	}
	settings := store.settings
	settings.Revision = 7
	return settings, nil
}

func (store *fakeStore) Save(_ context.Context, input Input) (Settings, error) {
	store.input = input
	store.called = true
	if store.err != nil {
		return Settings{}, store.err
	}
	return store.settings, nil
}
