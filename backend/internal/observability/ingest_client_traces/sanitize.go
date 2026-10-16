package ingestclienttraces

import (
	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	desktopupdate "voice-platform/backend/internal/observability/ingest_client_traces/desktop_update"
	voiceaudio "voice-platform/backend/internal/observability/ingest_client_traces/voice_audio"
	voicedisconnect "voice-platform/backend/internal/observability/ingest_client_traces/voice_disconnect"
	volumepreference "voice-platform/backend/internal/observability/ingest_client_traces/volume_preference"
)

var platforms = map[string]bool{"web": true, "android": true, "ios": true, "windows": true, "macos": true}

func sanitize(input *collectortrace.ExportTraceServiceRequest, platform string) (*collectortrace.ExportTraceServiceRequest, bool) {
	clean, result := sanitizeBatch(input, platform, "", "")
	return clean, !result.Fatal && result.Accepted > 0 && result.Rejected == 0
}
func cleanLegacy(span, clean *tracepb.Span, platform string) {
	clean.Events = safeClientEvents(span)
	clean.Attributes = audioInputAttributes(span, platform)
	switch span.Name {
	case "desktop.update":
		clean.Attributes = desktopupdate.Clean(span.Attributes, platform)
	case "voice.audio.sample":
		clean.Attributes = voiceaudio.Clean(span.Attributes, platform)
	case "voice.volume.preference":
		clean.Attributes = volumepreference.Clean(span.Attributes, platform)
	case "voice.disconnect":
		clean.Attributes = voicedisconnect.Clean(span.Attributes, platform)
	}
}
