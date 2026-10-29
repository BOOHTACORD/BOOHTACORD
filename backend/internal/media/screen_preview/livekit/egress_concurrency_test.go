package screenpreviewlivekit

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestSlowEgressControlForOneStreamDoesNotBlockAnother(t *testing.T) {
	blockedChannel, availableChannel := uuid.NewString(), uuid.NewString()
	entered := make(chan struct{})
	release := make(chan struct{})
	var releaseOnce sync.Once
	transport := roundTripFunc(func(request *http.Request) (*http.Response, error) {
		body, err := io.ReadAll(request.Body)
		if err != nil {
			return nil, err
		}
		request.Body = io.NopCloser(bytes.NewReader(body))
		if request.URL.Path == "/twirp/livekit.Egress/ListEgress" && bytes.Contains(body, []byte(blockedChannel)) {
			close(entered)
			<-release
		}
		result := `{"items":[]}`
		if request.URL.Path == "/twirp/livekit.Egress/StartParticipantEgress" {
			id := "EG_blocked"
			if bytes.Contains(body, []byte(availableChannel)) {
				id = "EG_available"
			}
			result = `{"egress_id":"` + id + `","status":"EGRESS_STARTING"}`
		}
		return &http.Response{StatusCode: http.StatusOK, Header: http.Header{"Content-Type": []string{"application/json"}}, Body: io.NopCloser(strings.NewReader(result)), Request: request}, nil
	})
	capture, err := NewCapturer(Config{URL: "http://livekit.test", APIKey: "api-key", APISecret: "api-secret", PreviewRoot: t.TempDir(), HTTPTransport: transport})
	if err != nil {
		t.Fatal(err)
	}
	blockedResult := make(chan error, 1)
	go func() {
		blockedResult <- capture.Ensure(context.Background(), blockedChannel, uuid.NewString(), uuid.NewString(), "screen-a")
	}()
	select {
	case <-entered:
	case <-time.After(time.Second):
		t.Fatal("first Egress control request did not enter the transport")
	}
	defer releaseOnce.Do(func() { close(release) })

	availableResult := make(chan error, 1)
	go func() {
		availableResult <- capture.Ensure(context.Background(), availableChannel, uuid.NewString(), uuid.NewString(), "screen-b")
	}()
	blockedUnrelatedStream := false
	select {
	case err := <-availableResult:
		if err != nil {
			t.Fatalf("unrelated Egress capture failed: %v", err)
		}
	case <-time.After(time.Second):
		blockedUnrelatedStream = true
	}
	releaseOnce.Do(func() { close(release) })
	if blockedUnrelatedStream {
		select {
		case <-availableResult:
		case <-time.After(time.Second):
			t.Fatal("unrelated Egress request did not finish after releasing the delayed request")
		}
	}
	select {
	case err := <-blockedResult:
		if err != nil {
			t.Fatalf("delayed Egress capture failed: %v", err)
		}
	case <-time.After(time.Second):
		t.Fatal("delayed Egress capture did not resume")
	}
	if blockedUnrelatedStream {
		t.Fatal("slow Egress request for one stream blocked an unrelated capture")
	}
}
