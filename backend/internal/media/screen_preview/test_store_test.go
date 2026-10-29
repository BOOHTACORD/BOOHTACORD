package screenpreview

import "github.com/google/uuid"

type testStore struct {
	lease, generation, channel, track string
	revision, reserved                uint64
	fingerprint                       string
	body                              []byte
}

func (store *testStore) Begin(lease, channel, track string) (string, error) {
	if store.generation != "" && store.channel == channel && store.track == track {
		return store.generation, nil
	}
	store.lease, store.generation, store.channel, store.track = lease, uuid.NewString(), channel, track
	store.revision, store.fingerprint, store.body = 0, "", nil
	return store.generation, nil
}
func (store *testStore) Current(lease string) (string, string, string, bool) {
	if lease != store.lease {
		return "", "", "", false
	}
	return store.generation, store.channel, store.track, store.generation != ""
}
func (store *testStore) Renew(lease, generation string) error {
	if generation != store.generation {
		return ErrStaleGeneration
	}
	return nil
}
func (store *testStore) Active() []ActiveGeneration {
	if store.generation == "" {
		return nil
	}
	return []ActiveGeneration{{LeaseID: store.lease, GenerationID: store.generation, ChannelID: store.channel, TrackSID: store.track}}
}
func (store *testStore) Capture(_ string, generation, fingerprint string, body []byte) (uint64, bool, error) {
	if generation != store.generation {
		return 0, false, ErrStaleGeneration
	}
	if fingerprint == store.fingerprint {
		return store.revision, false, nil
	}
	store.fingerprint, store.revision, store.body = fingerprint, store.revision+1, append([]byte(nil), body...)
	return store.revision, true, nil
}
func (store *testStore) Track(_ string, generation string) (string, error) {
	if generation != store.generation {
		return "", ErrStaleGeneration
	}
	return store.track, nil
}
func (store *testStore) Reserve(_ string, generation string, revision uint64) (string, error) {
	if generation != store.generation || revision <= store.revision {
		return "", ErrStaleGeneration
	}
	store.reserved = revision
	return store.track, nil
}
func (store *testStore) Commit(_ string, generation string, revision uint64, body []byte) error {
	if generation != store.generation || revision != store.reserved {
		return ErrStaleGeneration
	}
	store.body, store.revision = append([]byte(nil), body...), revision
	return nil
}
func (store *testStore) Read(_ string, generation string) ([]byte, uint64, bool, error) {
	if generation != store.generation {
		return nil, 0, false, ErrStaleGeneration
	}
	return append([]byte(nil), store.body...), store.revision, len(store.body) > 0, nil
}
func (store *testStore) Invalidate(_ string, generation string) error {
	if generation == store.generation {
		store.body = nil
		store.generation = ""
	}
	return nil
}
