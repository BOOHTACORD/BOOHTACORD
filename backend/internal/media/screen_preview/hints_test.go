package screenpreview

import (
	"context"
	"github.com/google/uuid"
	"testing"
)

type testHints struct {
	updates, invalidations int
	lease, generation      string
	revision               uint64
}

func (hints *testHints) Updated(_ context.Context, lease, generation string, revision uint64) {
	hints.updates++
	hints.lease, hints.generation, hints.revision = lease, generation, revision
}
func (hints *testHints) Invalidated(_ context.Context, lease, generation string) {
	hints.invalidations++
	hints.lease, hints.generation = lease, generation
}

func TestServerCaptureAndInvalidationPublishMetadataHints(t *testing.T) {
	hints := &testHints{}
	lease := uuid.NewString()
	store, capture := &testStore{}, &captureStub{frame: CaptureFrame{Fingerprint: "frame-1", JPEG: validCaptureJPEG(t)}}
	service, err := New(testAuthority{owner: true, viewer: true, channel: uuid.NewString()}, &testPublication{track: "track"}, store, capture, hints)
	if err != nil {
		t.Fatal(err)
	}
	generation, err := service.Begin(context.Background(), Principal{}, lease)
	if err != nil {
		t.Fatal(err)
	}
	if err := service.PollCaptures(context.Background()); err != nil {
		t.Fatal(err)
	}
	if hints.updates != 1 || hints.lease != lease || hints.generation != generation.GenerationID || hints.revision != 1 {
		t.Fatalf("server capture hint = %+v", hints)
	}
	if err := service.Invalidate(context.Background(), Principal{}, lease, generation.GenerationID); err != nil {
		t.Fatal(err)
	}
	if hints.invalidations != 1 || hints.generation != generation.GenerationID {
		t.Fatalf("invalidation hint = %+v", hints)
	}
}
