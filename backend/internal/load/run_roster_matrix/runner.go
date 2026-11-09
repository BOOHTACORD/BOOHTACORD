package runrostermatrix

import (
	"context"
	"time"

	chat "voice-platform/backend/internal/load/matrix_chat"
	"voice-platform/backend/internal/load/observe_resources"
	"voice-platform/backend/internal/load/validate_target"
)

type Report struct {
	Outcome, StopReason, Mode, Media string
	SourceProfile                    string
	Accounts, Rooms                  int
	Measurements                     map[string]Summary
	Resources                        []observe_resources.Snapshot
	Message                          *MessageReport
	MessageWarmupMS                  int
}

func RunWithWarmup(parent context.Context, manifest validate_target.Manifest, mode string, sameSource, maintenanceChange bool, messages, warmupMS int) (report Report) {
	profile := "independent"
	if sameSource {
		profile = "shared"
	}
	report = Report{Outcome: "FAIL", StopReason: "preflight", Mode: mode, Media: "NOT_RUN", SourceProfile: profile, Accounts: len(manifest.Accounts), Rooms: len(manifest.Voice), MessageWarmupMS: warmupMS}
	if sameSource && len(manifest.Accounts) != 20 {
		return
	}
	if manifest.ValidateRosterMatrix() != nil || (mode != "candidate" && mode != "baseline") || manifest.MaxSeconds < 20 || manifest.MaxSeconds > 600 || messages < 0 || messages > 20 || warmupMS < 0 || warmupMS > 2000 || (warmupMS != 0 && messages == 0) {
		return
	}
	requestsPerAccount := 3
	if mode == "baseline" {
		requestsPerAccount = 5
	}
	if manifest.MaxRequests < len(manifest.Accounts)*requestsPerAccount+messages {
		return
	}
	ctx, cancel := context.WithTimeout(parent, time.Duration(manifest.MaxSeconds)*time.Second)
	defer cancel()
	guard := observe_resources.Guard{Manifest: manifest, Client: validate_target.Client()}
	initial, err := guard.Check(ctx)
	if err != nil || initial.MetricsStatus != "AVAILABLE" {
		report.StopReason = "guard_preflight"
		return
	}
	watch := &monitor{samples: []observe_resources.Snapshot{initial}}
	done := make(chan struct{})
	go func() { defer close(done); watch.run(ctx, cancel, guard) }()
	measurements := NewMeasurements(len(manifest.Accounts))
	var collector *chat.Collector
	if messages > 0 {
		collector, _ = chat.New(len(manifest.Accounts))
	}
	var actors []*Actor
	defer func() {
		cancel()
		for _, actor := range actors {
			actor.Close()
		}
		<-done
		var failed bool
		report.Resources, failed = watch.result()
		report.Measurements = measurements.Snapshot()
		if failed {
			report.Outcome, report.StopReason = "FAIL", "guard_stop"
		}
	}()
	for i := range manifest.Accounts {
		if anyFailed(actors) {
			report.StopReason = "stream_failure"
			return
		}
		actor, startErr := StartActorWithMessages(ctx, actorClient(i, sameSource), manifest, i, mode == "baseline", measurements, collector)
		if startErr != nil {
			report.StopReason = "actor_start"
			return
		}
		actors = append(actors, actor)
	}
	var work func(context.Context) error
	if collector != nil {
		work = func(ctx context.Context) error {
			if err := waitMessageWarmup(ctx, warmupMS); err != nil {
				return err
			}
			result, err := measureMessagesWithProbe(ctx, collector, messages, func(ctx context.Context) (string, error) {
				return chat.Send(ctx, actors[0].client, manifest.Origin, manifest.Text)
			}, serverDeliveryProbe(guard))
			report.Message = &result
			return err
		}
	}
	report.Outcome, report.StopReason = waitForSteady(ctx, actors, measurements, guard, maintenanceChange, work)
	return
}

func anyFailed(actors []*Actor) bool {
	for _, actor := range actors {
		if actor.Failed() {
			return true
		}
	}
	return false
}
