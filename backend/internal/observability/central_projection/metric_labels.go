package centralprojection

import "strings"

// Fixed dimensions already emitted by approved product instruments. Preserve
// these so sanitization cannot fold distinct gauges/histograms into one series.
func enum(values ...string) map[string]bool {
	out := make(map[string]bool, len(values))
	for _, v := range values {
		out[v] = true
	}
	return out
}

var extraLabelValues = map[string]map[string]bool{
	"method":         enum("ListRooms", "ListParticipants", "other", "OTHER", "CONNECT", "TRACE"),
	"source":         enum("client_report"),
	"state":          enum("waiting_subscription"),
	"stat":           enum("empty_acquires", "canceled_acquires", "acquired", "idle", "total", "max", "constructing", "participants", "streams", "screen_streams"),
	"outcome":        enum("success", "failure", "failed", "canceled", "timeout", "error", "transport_error", "http_error", "overload", "started", "finished", "shared", "cached", "overloaded", "published", "skipped_disabled", "skipped_channel_unavailable", "rejected", "conflict", "accepted"),
	"operation":      enum("livekit_probe", "storage_probe", "livekit_snapshot", "storage_snapshot", "livekit_list_rooms", "livekit_list_participants", "livekit_other", "livekit_remove", "trace_export", "metric_export", "relay_export", "lease_notification_worker", "channel_finalization_worker", "sfu_revocation_worker", "realtime_journal", "metrics_scrape", "health", "maintenance", "maintenance_events", "session_probe", "trace_relay", "screen_report", "roster_events", "media_admission", "roster_hook"),
	"class":          enum("dns", "connect", "reset", "timeout", "canceled", "other"),
	"status_class":   enum("401", "403", "404", "5xx", "other"),
	"freshness":      enum("fresh", "stale", "legacy"),
	"age_provenance": enum("known", "legacy"),
	"availability":   enum("present", "missing", "stale"),
	"role":           enum("target", "actual_short_edge"),
	"stage":          enum("encoded", "decoded", "presented", "list_rooms", "list_participants", "snapshot", "encode", "write", "publish", "database", "realtime"),
	"field":          enum("fps", "fps_target_ratio", "target_fps", "resolution_pixels", "resolution_target_ratio", "bitrate_kbps", "rtt_milliseconds", "jitter_milliseconds", "packet_loss_percent", "packet_loss_window_milliseconds", "dropped_frames", "sample_age_milliseconds"),
	"quality":        enum("UNKNOWN", "EXCELLENT", "GOOD", "POOR", "LOST", "unreported"),
	"reason":         enum("unsupported", "malformed", "size", "session_mismatch", "collector_rejected", "none", "cpu", "bandwidth", "other", "unreported", "canceled", "session_expired", "session_store", "snapshot", "write", "invalid_payload", "rate_limited", "disabled", "policy", "unavailable"),
}
var metricRoutes = func() map[string]bool {
	out := map[string]bool{"unmatched": true}
	for operation := range OperationNames {
		method, path, ok := strings.Cut(operation, " ")
		if ok && labelValues["method"][method] {
			out[path] = true
		}
	}
	return out
}()
