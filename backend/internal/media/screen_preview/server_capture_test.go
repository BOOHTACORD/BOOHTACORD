package screenpreview

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/color"
	"image/jpeg"
	"testing"

	"github.com/google/uuid"
)

type captureStub struct {
	starts, stops int
	startErr      error
	frame         CaptureFrame
}

func (capture *captureStub) Ensure(context.Context, string, string, string, string) error {
	capture.starts++
	return capture.startErr
}
func (capture *captureStub) Stop(context.Context, string, string, string) error {
	capture.stops++
	return nil
}
func (capture *captureStub) Latest(context.Context, string, string) (CaptureFrame, error) {
	return capture.frame, nil
}
func (capture *captureStub) Active() []CaptureSession { return nil }

type hintsStub struct {
	updated, invalidated int
	lastRevision         uint64
}

func (hints *hintsStub) Updated(context.Context, string, string, uint64) {
	hints.updated++
	hints.lastRevision++
}
func (hints *hintsStub) Invalidated(context.Context, string, string) { hints.invalidated++ }

func TestBeginStartsOneServerCaptureAndRefreshesItsLease(t *testing.T) {
	channelID, leaseID := uuid.NewString(), uuid.NewString()
	publication := &testPublication{track: "screen-track"}
	store, capture := &testStore{}, &captureStub{}
	service, err := New(testAuthority{owner: true, channel: channelID}, publication, store, capture)
	if err != nil {
		t.Fatal(err)
	}
	first, err := service.Begin(context.Background(), Principal{AccountID: uuid.NewString()}, leaseID)
	if err != nil {
		t.Fatal(err)
	}
	second, err := service.Begin(context.Background(), Principal{AccountID: uuid.NewString()}, leaseID)
	if err != nil {
		t.Fatal(err)
	}
	if first.GenerationID == "" || second.GenerationID != first.GenerationID || capture.starts != 2 {
		t.Fatalf("first=%+v second=%+v capture starts=%d", first, second, capture.starts)
	}
}

func TestServerFramesBecomeAuthorizedRevisionsAndNotifyViewers(t *testing.T) {
	channelID, leaseID := uuid.NewString(), uuid.NewString()
	publication := &testPublication{track: "screen-track"}
	store, capture, hints := &testStore{}, &captureStub{frame: CaptureFrame{Fingerprint: "f1", JPEG: validCaptureJPEG(t)}}, &hintsStub{}
	service, err := New(testAuthority{owner: true, viewer: true, channel: channelID}, publication, store, capture, hints)
	if err != nil {
		t.Fatal(err)
	}
	generation, err := service.Begin(context.Background(), Principal{AccountID: uuid.NewString()}, leaseID)
	if err != nil {
		t.Fatal(err)
	}
	if err := service.PollCaptures(context.Background()); err != nil {
		t.Fatal(err)
	}
	preview, err := service.Read(context.Background(), Principal{}, leaseID, generation.GenerationID, 0)
	if err != nil || preview.Revision != 1 || ValidateJPEG(preview.JPEG) != nil || hints.updated != 1 {
		t.Fatalf("preview=%+v hint updates=%d err=%v", preview, hints.updated, err)
	}
	if err := service.PollCaptures(context.Background()); err != nil {
		t.Fatal(err)
	}
	if hints.updated != 1 {
		t.Fatalf("unchanged server frame emitted %d updates", hints.updated)
	}
	capture.frame = CaptureFrame{Fingerprint: "f2", JPEG: validCaptureJPEG(t)}
	if err := service.PollCaptures(context.Background()); err != nil {
		t.Fatal(err)
	}
	preview, err = service.Read(context.Background(), Principal{}, leaseID, generation.GenerationID, 1)
	if err != nil || preview.Revision != 2 || ValidateJPEG(preview.JPEG) != nil || hints.updated != 2 {
		t.Fatalf("second preview=%+v hint updates=%d err=%v", preview, hints.updated, err)
	}
}

func TestBeginFailureDoesNotLeaveAnActiveGeneration(t *testing.T) {
	leaseID := uuid.NewString()
	store, capture := &testStore{}, &captureStub{startErr: errors.New("egress offline")}
	service, err := New(testAuthority{owner: true, channel: uuid.NewString()}, &testPublication{track: "screen-track"}, store, capture)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := service.Begin(context.Background(), Principal{}, leaseID); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("begin error = %v", err)
	}
	if store.generation != "" || capture.stops != 1 {
		t.Fatalf("failed start left generation %q and stops=%d", store.generation, capture.stops)
	}
}

func TestHeartbeatStopsTheCaptureWhenTheScreenTrackWasUnpublished(t *testing.T) {
	leaseID := uuid.NewString()
	publication := &testPublication{track: "screen-track"}
	store, capture := &testStore{}, &captureStub{}
	service, err := New(testAuthority{owner: true, channel: uuid.NewString()}, publication, store, capture)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := service.Begin(context.Background(), Principal{}, leaseID); err != nil {
		t.Fatal(err)
	}
	publication.err = ErrNoPublication
	if _, err := service.Begin(context.Background(), Principal{}, leaseID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("unpublished heartbeat error = %v", err)
	}
	if store.generation != "" || capture.stops != 1 {
		t.Fatalf("unpublished screen left generation %q and stopped %d captures", store.generation, capture.stops)
	}
}

func TestInvalidateStopsCaptureAndClientJPEGUploadIsDisabled(t *testing.T) {
	leaseID := uuid.NewString()
	store, capture := &testStore{}, &captureStub{}
	service, err := New(testAuthority{owner: true, channel: uuid.NewString()}, &testPublication{track: "screen-track"}, store, capture)
	if err != nil {
		t.Fatal(err)
	}
	generation, err := service.Begin(context.Background(), Principal{}, leaseID)
	if err != nil {
		t.Fatal(err)
	}
	if err := service.Upload(context.Background(), Principal{}, leaseID, generation.GenerationID, 1, validCaptureJPEG(t)); !errors.Is(err, ErrServerManaged) {
		t.Fatalf("client upload error = %v", err)
	}
	if err := service.Invalidate(context.Background(), Principal{}, leaseID, generation.GenerationID); err != nil {
		t.Fatal(err)
	}
	if capture.stops != 1 || store.generation != "" {
		t.Fatalf("capture stops=%d generation=%q", capture.stops, store.generation)
	}
}

func validCaptureJPEG(t *testing.T) []byte {
	t.Helper()
	frame := image.NewRGBA(image.Rect(0, 0, 8, 8))
	frame.Set(0, 0, color.RGBA{R: 255, A: 255})
	var encoded bytes.Buffer
	if err := jpeg.Encode(&encoded, frame, &jpeg.Options{Quality: 70}); err != nil {
		t.Fatal(err)
	}
	return encoded.Bytes()
}
