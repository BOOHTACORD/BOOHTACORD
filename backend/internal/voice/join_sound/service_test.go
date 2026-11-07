package joinsound

import (
	"context"
	"errors"
	"testing"
)

const owner = "11111111-1111-4111-8111-111111111111"

type storeFake struct {
	value             Sound
	allowed, reserved bool
	writes            int
}

func (s *storeFake) Reserve(context.Context, string) (bool, error) { return s.reserved, nil }
func (s *storeFake) Replace(_ context.Context, account string, data Audio) (Sound, error) {
	s.writes++
	s.value = Sound{ID: owner, Owner: account, Revision: 1, Enabled: true, Audio: data}
	return s.value, nil
}
func (s *storeFake) Fetch(_ context.Context, _ Actor, _ string) (Sound, error) {
	if !s.allowed {
		return Sound{}, ErrNotFound
	}
	return s.value, nil
}

type processorFake struct {
	calls int
	err   error
}

func (p *processorFake) Process(context.Context, []byte) (Audio, error) {
	p.calls++
	return Audio{Bytes: []byte{1}, DurationMS: 1000}, p.err
}
func TestUploadRejectsOversizeBeforeProcessingAndRateLimits(t *testing.T) {
	s, p := &storeFake{reserved: true}, &processorFake{}
	service := New(s, p)
	if _, err := service.Upload(context.Background(), owner, make([]byte, MaxInput+1)); !errors.Is(err, ErrInvalid) || p.calls != 0 {
		t.Fatal("oversize reached processor")
	}
	s.reserved = false
	if _, err := service.Upload(context.Background(), owner, []byte{1}); !errors.Is(err, ErrRateLimited) || p.calls != 0 {
		t.Fatal("rate limit bypass")
	}
}
func TestUploadFailsClosedAndPublishesOnlyProcessedAudio(t *testing.T) {
	s, p := &storeFake{reserved: true}, &processorFake{err: ErrUnavailable}
	service := New(s, p)
	if _, err := service.Upload(context.Background(), owner, []byte{1}); !errors.Is(err, ErrUnavailable) || s.writes != 0 {
		t.Fatal("processor failure replaced sound")
	}
	p.err = nil
	sound, err := service.Upload(context.Background(), owner, []byte{1})
	if err != nil || sound.Owner != owner || s.writes != 1 {
		t.Fatal("processed sound not stored")
	}
}
func TestDownloadRequiresRepositoryAuthorization(t *testing.T) {
	s := &storeFake{value: Sound{ID: owner, Enabled: true}}
	service := New(s, &processorFake{})
	if _, err := service.Download(context.Background(), Actor{Account: owner}, owner); !errors.Is(err, ErrNotFound) {
		t.Fatal("private audio exposed")
	}
	s.allowed = true
	if _, err := service.Download(context.Background(), Actor{Account: owner}, owner); err != nil {
		t.Fatal(err)
	}
}
