package httpmetrics

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

type voiceRosterMetrics struct {
	snapshots *prometheus.CounterVec
	failures  *prometheus.CounterVec
	duration  prometheus.Histogram
	rooms     prometheus.Histogram
	calls     *prometheus.CounterVec
}

func newVoiceRosterMetrics() *voiceRosterMetrics {
	return &voiceRosterMetrics{
		calls:     prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_sfu_room_service_calls_total", Help: "Actual RoomService HTTP calls; bounded method and outcome only."}, []string{"method", "outcome"}),
		snapshots: prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_voice_roster_snapshots_total", Help: "SFU roster snapshot attempts by outcome."}, []string{"outcome"}),
		failures:  prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_voice_roster_failures_total", Help: "Voice roster load failures by bounded processing stage; no IDs or error text are recorded."}, []string{"stage"}),
		duration:  prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_voice_roster_snapshot_seconds", Help: "SFU roster snapshot latency, excluding database ACL checks."}),
		rooms:     prometheus.NewHistogram(prometheus.HistogramOpts{Name: "voice_platform_voice_roster_requested_rooms", Help: "Visible room count requested from SFU per roster snapshot."}),
	}
}

func (recorder *Recorder) ObserveSFURoomServiceCall(method string, failed bool) {
	if method != "ListRooms" && method != "ListParticipants" {
		method = "other"
	}
	outcome := "success"
	if failed {
		outcome = "failure"
	}
	recorder.roster.calls.WithLabelValues(method, outcome).Inc()
}

func (recorder *Recorder) ObserveVoiceRosterFailure(stage string) {
	switch stage {
	case "visibility_initial", "visibility_initial_timeout", "visibility_initial_canceled", "presence_snapshot", "presence_snapshot_timeout", "presence_snapshot_canceled", "presence_validation", "presence_token", "presence_room_list", "presence_participants", "visibility_recheck", "visibility_recheck_timeout", "visibility_recheck_canceled":
	default:
		stage = "unknown"
	}
	recorder.rosterDependencies.Failure(stage)
	recorder.roster.failures.WithLabelValues(stage).Inc()
}

func (recorder *Recorder) ObserveVoiceRosterSnapshot(duration time.Duration, requestedRooms int, failed bool) {
	outcome := "success"
	if failed {
		outcome = "failure"
	}
	recorder.rosterDependencies.Snapshot(duration, requestedRooms, failed)
	recorder.roster.snapshots.WithLabelValues(outcome).Inc()
	recorder.roster.duration.Observe(duration.Seconds())
	recorder.roster.rooms.Observe(float64(requestedRooms))
}

func (recorder *Recorder) ObserveSFURoomServiceDuration(method, outcome string, elapsed time.Duration) {
	recorder.rosterDependencies.Call(method, outcome, elapsed)
}

func (recorder *Recorder) ObserveVoicePresenceGate(outcome string) {
	recorder.rosterDependencies.Gate(outcome)
}

func (recorder *Recorder) ObserveSFURoomServiceConfigured(configured bool) {
	recorder.rosterDependencies.Configured(configured)
}
func (recorder *Recorder) ObserveSFURoomServiceFailureClass(method, class, status string) {
	recorder.rosterDependencies.FailureClass(method, class, status)
}
