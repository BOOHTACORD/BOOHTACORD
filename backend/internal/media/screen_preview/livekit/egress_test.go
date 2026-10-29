package screenpreviewlivekit

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"image"
	"image/color"
	"image/jpeg"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/livekit/protocol/livekit"
	"google.golang.org/protobuf/encoding/protojson"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

func TestExistingSharedVolumeDoesNotRequireOwnerForChmod(t *testing.T) {
	root := t.TempDir()
	if err := os.Chmod(root, 0o777); err != nil {
		t.Fatal(err)
	}
	called := false
	err := ensureWorldWritableDirectoryWith(root, func(string, os.FileMode) error {
		called = true
		return errors.New("permission denied")
	})
	if err != nil || called {
		t.Fatalf("ensure shared directory err=%v chmod called=%v", err, called)
	}
}

func TestEnsureStartsTrackScopedThirtySecondPrivateJPEGOutput(t *testing.T) {
	channelID, leaseID, generationID := uuid.NewString(), uuid.NewString(), uuid.NewString()
	var start map[string]any
	var listCalls, startCalls int
	transport := roundTripFunc(func(request *http.Request) (*http.Response, error) {
		var body string
		switch request.URL.Path {
		case "/twirp/livekit.Egress/ListEgress":
			listCalls++
			body = `{"items":[]}`
		case "/twirp/livekit.Egress/StartParticipantEgress":
			startCalls++
			if err := json.NewDecoder(request.Body).Decode(&start); err != nil {
				t.Errorf("decode Egress request: %v", err)
			}
			body = `{"egress_id":"EG_test","status":"EGRESS_STARTING"}`
		default:
			t.Errorf("unexpected LiveKit request path %q", request.URL.Path)
			return &http.Response{StatusCode: http.StatusNotFound, Header: http.Header{}, Body: io.NopCloser(strings.NewReader("")), Request: request}, nil
		}
		return &http.Response{StatusCode: http.StatusOK, Header: http.Header{"Content-Type": []string{"application/json"}}, Body: io.NopCloser(strings.NewReader(body)), Request: request}, nil
	})
	root := t.TempDir()
	capture, err := NewCapturer(Config{URL: "http://livekit.test", APIKey: "api-key", APISecret: "api-secret", PreviewRoot: root, HTTPTransport: transport})
	if err != nil {
		t.Fatal(err)
	}
	if err := capture.Ensure(context.Background(), channelID, leaseID, generationID, "screen-track"); err != nil {
		t.Fatal(err)
	}
	if err := capture.Ensure(context.Background(), channelID, leaseID, generationID, "screen-track"); err != nil {
		t.Fatal(err)
	}
	if listCalls != 1 || startCalls != 1 {
		t.Fatalf("idempotent Ensure made %d list and %d start calls", listCalls, startCalls)
	}
	if start["room_name"] != "voice:"+channelID || start["screen_share"] != true {
		t.Fatalf("Egress room/screen-share selector = %#v", start)
	}
	if start["identity"] != "voice-lease:"+leaseID {
		t.Fatalf("Egress identity = %#v", start["identity"])
	}
	outputs, ok := start["image_outputs"].([]any)
	if !ok || len(outputs) != 1 {
		t.Fatalf("image outputs = %#v", start["image_outputs"])
	}
	output, ok := outputs[0].(map[string]any)
	if !ok || output["capture_interval"] != float64(30) || output["image_codec"] != "IC_JPEG" || output["disable_manifest"] != true {
		t.Fatalf("image output = %#v", outputs[0])
	}
	if output["s3"] != nil || output["gcp"] != nil || output["azure"] != nil || output["aliOSS"] != nil {
		t.Fatalf("preview output is not private local storage: %#v", output)
	}
	prefix, ok := output["filename_prefix"].(string)
	if !ok || !strings.Contains(prefix, leaseID) || !strings.Contains(prefix, generationID) || !filepath.IsAbs(prefix) {
		t.Fatalf("unsafe preview output prefix = %#v", output["filename_prefix"])
	}
}

func TestFailedStartCanStopEgressWhenStartResponseWasLost(t *testing.T) {
	channelID, leaseID, generationID := uuid.NewString(), uuid.NewString(), uuid.NewString()
	var capture *Capturer
	var listCalls, stopCalls int
	transport := roundTripFunc(func(request *http.Request) (*http.Response, error) {
		var body string
		switch request.URL.Path {
		case "/twirp/livekit.Egress/ListEgress":
			listCalls++
			if listCalls == 1 {
				body = `{"items":[]}`
			} else {
				prefix, _ := capture.output(leaseID, generationID)
				info := &livekit.EgressInfo{
					EgressId: "EG_response_lost",
					RoomName: "voice:" + channelID,
					Status:   livekit.EgressStatus_EGRESS_STARTING,
					Request: &livekit.EgressInfo_Participant{Participant: &livekit.ParticipantEgressRequest{
						RoomName: "voice:" + channelID, Identity: "voice-lease:" + leaseID, ScreenShare: true,
						ImageOutputs: []*livekit.ImageOutput{{FilenamePrefix: prefix}},
					}},
				}
				encoded, err := protojson.Marshal(&livekit.ListEgressResponse{Items: []*livekit.EgressInfo{info}})
				if err != nil {
					t.Errorf("encode Egress list: %v", err)
				}
				body = string(encoded)
			}
		case "/twirp/livekit.Egress/StartParticipantEgress":
			return &http.Response{StatusCode: http.StatusInternalServerError, Header: http.Header{"Content-Type": []string{"application/json"}}, Body: io.NopCloser(strings.NewReader(`{"code":"internal","msg":"lost response"}`)), Request: request}, nil
		case "/twirp/livekit.Egress/StopEgress":
			stopCalls++
			body = `{"egress_id":"EG_response_lost"}`
		default:
			t.Errorf("unexpected Egress request path %q", request.URL.Path)
			return &http.Response{StatusCode: http.StatusNotFound, Header: http.Header{}, Body: io.NopCloser(strings.NewReader("")), Request: request}, nil
		}
		return &http.Response{StatusCode: http.StatusOK, Header: http.Header{"Content-Type": []string{"application/json"}}, Body: io.NopCloser(strings.NewReader(body)), Request: request}, nil
	})
	var err error
	capture, err = NewCapturer(Config{URL: "http://livekit.test", APIKey: "api-key", APISecret: "api-secret", PreviewRoot: t.TempDir(), HTTPTransport: transport})
	if err != nil {
		t.Fatal(err)
	}
	if err := capture.Ensure(context.Background(), channelID, leaseID, generationID, "screen-track"); err == nil {
		t.Fatal("lost Egress start response was accepted")
	}
	if err := capture.Stop(context.Background(), leaseID, generationID, "screen-track"); err != nil {
		t.Fatalf("stop after ambiguous start failed: %v", err)
	}
	if listCalls != 2 || stopCalls != 1 || len(capture.Active()) != 0 {
		t.Fatalf("lists=%d stops=%d active=%+v", listCalls, stopCalls, capture.Active())
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (roundTrip roundTripFunc) RoundTrip(request *http.Request) (*http.Response, error) {
	return roundTrip(request)
}

func TestLatestReadsOnlyBoundedJPEGsFromTheGenerationDirectory(t *testing.T) {
	leaseID, generationID := uuid.NewString(), uuid.NewString()
	root := t.TempDir()
	capture, err := NewCapturer(Config{URL: "http://127.0.0.1:1", APIKey: "api-key", APISecret: "api-secret", PreviewRoot: root})
	if err != nil {
		t.Fatal(err)
	}
	if err := capture.prepareDirectory(leaseID, generationID); err != nil {
		t.Fatal(err)
	}
	capture.active[captureKey(leaseID, generationID)] = captureEntry{
		session: screenpreview.CaptureSession{LeaseID: leaseID, GenerationID: generationID},
	}
	path := filepath.Join(capture.directory(leaseID, generationID), "frame.jpeg")
	if err := os.WriteFile(path, egressTestJPEG(t), 0o600); err != nil {
		t.Fatal(err)
	}
	frame, err := capture.Latest(context.Background(), leaseID, generationID)
	if err != nil || frame.Fingerprint == "" || screenpreview.ValidateJPEG(frame.JPEG) != nil {
		t.Fatalf("frame=%+v err=%v", frame, err)
	}
}

func egressTestJPEG(t *testing.T) []byte {
	t.Helper()
	frame := image.NewRGBA(image.Rect(0, 0, 4, 4))
	frame.Set(0, 0, color.RGBA{B: 255, A: 255})
	var encoded bytes.Buffer
	if err := jpeg.Encode(&encoded, frame, &jpeg.Options{Quality: 60}); err != nil {
		t.Fatal(err)
	}
	return encoded.Bytes()
}
