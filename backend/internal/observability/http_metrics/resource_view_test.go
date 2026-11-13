package httpmetrics

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type blockedVoiceMedia struct{ release <-chan struct{} }

func (source blockedVoiceMedia) Snapshot(ctx context.Context) (VoiceMediaSnapshot, error) {
	select {
	case <-source.release:
		return VoiceMediaSnapshot{}, nil
	case <-ctx.Done():
		return VoiceMediaSnapshot{}, ctx.Err()
	}
}

func TestResourceViewRemainsAvailableDuringVoiceMediaOutage(t *testing.T) {
	release := make(chan struct{})
	defer close(release)
	recorder := New()
	if err := recorder.RegisterVoiceMedia(blockedVoiceMedia{release}); err != nil {
		t.Fatal(err)
	}
	if err := recorder.RegisterAttachmentFilesystem(fakeAttachmentFilesystem{snapshot: AttachmentFilesystemSnapshot{AvailableBytes: 7, TotalBytes: 11}}); err != nil {
		t.Fatal(err)
	}
	result := make(chan string, 1)
	go func() {
		response := httptest.NewRecorder()
		recorder.Handler().ServeHTTP(response, httptest.NewRequest("GET", "/metrics?view=resources", nil))
		result <- response.Body.String()
	}()
	select {
	case metrics := <-result:
		for _, want := range []string{"process_cpu_seconds_total", "process_resident_memory_bytes", "voice_platform_attachment_filesystem_available_bytes 7"} {
			if !strings.Contains(metrics, want) {
				t.Fatalf("resource view missing %q", want)
			}
		}
		if strings.Contains(metrics, "voice_platform_voice_media_snapshot_success") {
			t.Fatal("resource view unexpectedly collected voice media")
		}
	case <-time.After(time.Second):
		t.Fatal("resource view blocked on voice media")
	}
}
