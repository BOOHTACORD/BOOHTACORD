package reportscreenapi

import (
	"context"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	bindflow "voice-platform/backend/internal/observability/bind_flow"
	correlation "voice-platform/backend/internal/observability/correlate_session"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

// This endpoint does not make an HTTP trace. A fresh bounded measurement gets
// its own span after validation, with identity from the authenticated request.
func recordMediaSample(ctx context.Context, report httpmetrics.ClientScreenReport, mediaSessionID string) {
	principal, ok := sessionapi.PrincipalFrom(ctx)
	if !ok || principal.AccountID == "" {
		return
	}
	attrs := correlation.NamedAttributes(principal.AccountID, principal.SessionDigest, principal.DisplayName)
	// Flow context is accepted only by the authenticated session guard. Preserve
	// its visit/attempt, while the active lease lookup remains authoritative for
	// media session identity. Reported measurements are client observations.
	if flow, ok := bindflow.From(ctx); ok {
		for _, attr := range flow.Attributes() {
			if attr.Key != "app.media.session.id" && attr.Key != "app.provenance" {
				attrs = append(attrs, attr)
			}
		}
	}
	attrs = append(attrs, attribute.String("app.provenance", "client_observed"))
	if platform := sampleClientPlatform(report.Platform); platform != "" {
		attrs = append(attrs, attribute.String("client.platform", platform))
	}
	if mediaSessionID != "" {
		attrs = append(attrs, attribute.String("app.media.session.id", mediaSessionID))
	}
	attrs = append(attrs, measurementAttributes(report.Measurement)...)
	attrs = append(attrs, attribute.String("media.platform", report.Platform),
		attribute.String("media.direction", report.Direction), attribute.String("media.state", report.State),
		attribute.String("media.measurement_source", "client_webrtc"))
	for name, value := range map[string]*float64{
		"encoded_fps": report.EncodedFPS, "decoded_fps": report.DecodedFPS, "presented_fps": report.PresentedFPS,
		"bitrate_kbps": report.BitrateKbps, "rtt_ms": report.RTTMs, "jitter_ms": report.JitterMs,
		"packet_loss_percent": report.PacketLossPercent, "packet_loss_window_ms": report.PacketLossWindowMs,
		"target_resolution": report.TargetResolution, "target_fps": report.TargetFPS, "sample_age_ms": report.SampleAgeMs,
		"capture_fps": report.CaptureFPS,
	} {
		if value != nil {
			attrs = append(attrs, attribute.Float64("media."+name, *value))
		}
	}
	if report.FrameWidth != nil {
		attrs = append(attrs, attribute.Int("media.frame_width", *report.FrameWidth), attribute.Int("media.frame_height", *report.FrameHeight))
	}
	if report.ConnectionQuality != "" {
		attrs = append(attrs, attribute.String("media.connection_quality", report.ConnectionQuality))
	}
	if report.AdaptationReason != "" {
		attrs = append(attrs, attribute.String("media.adaptation_reason", report.AdaptationReason))
	}
	if report.ProfileCheckStatus != "" {
		attrs = append(attrs, attribute.String("media.profile_check_status", report.ProfileCheckStatus),
			attribute.String("media.profile_check_reason", report.ProfileCheckReason),
			attribute.Int("media.profile_repair_attempts", *report.ProfileRepairAttempts))
	}
	if report.CaptureWidth != nil {
		attrs = append(attrs, attribute.Int("media.capture_width", *report.CaptureWidth), attribute.Int("media.capture_height", *report.CaptureHeight))
	}
	for name, value := range map[string]*int64{"dropped_frames": report.DroppedFrames, "packets_lost": report.PacketsLost} {
		if value != nil {
			attrs = append(attrs, attribute.Int64("media."+name, *value))
		}
	}
	// Age is relative to collection, avoiding dependence on the client's wall clock.
	at := time.Now()
	if report.SampleAgeMs != nil {
		at = at.Add(-time.Duration(*report.SampleAgeMs * float64(time.Millisecond)))
	}
	_, span := otel.Tracer("boohtacord/media").Start(ctx, "media.sample", trace.WithNewRoot(), trace.WithTimestamp(at), trace.WithAttributes(attrs...))
	span.End(trace.WithTimestamp(at))
}
