package soundprocessor

import (
	"context"
	"errors"
	"net/http/httptest"
	"testing"
	s "voice-platform/backend/internal/voice/join_sound"
)

type fixedProcessor struct{}

func (fixedProcessor) Process(context.Context, []byte) (s.Audio, error) {
	return s.Audio{Bytes: []byte{1, 2}, DurationMS: 1000}, nil
}
func TestRemoteWorkerTransfersOnlyBoundedAudio(t *testing.T) {
	server := httptest.NewServer(NewWorker(fixedProcessor{}))
	defer server.Close()
	remote, err := NewRemote(server.URL + "/normalize")
	if err != nil {
		t.Fatal(err)
	}
	audio, err := remote.Process(context.Background(), []byte{1})
	if err != nil || len(audio.Bytes) != 2 || audio.DurationMS != 1000 {
		t.Fatal("worker response", err)
	}
	if _, err = remote.Process(context.Background(), make([]byte, s.MaxInput+1)); !errors.Is(err, s.ErrInvalid) {
		t.Fatal("oversize request", err)
	}
}
func TestRemoteWorkerRejectsExternalOrCredentialledEndpoints(t *testing.T) {
	for _, endpoint := range []string{"https://evil.example/normalize", "http://user:secret@join-sound-processor:8090/normalize", "http://join-sound-processor:8090/normalize?url=x"} {
		if _, err := NewRemote(endpoint); err == nil {
			t.Fatal("unsafe endpoint accepted")
		}
	}
}
