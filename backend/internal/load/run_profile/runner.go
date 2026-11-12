package run_profile

import (
	"context"
	"time"
	"voice-platform/backend/internal/load/exercise_actor"
	"voice-platform/backend/internal/load/observe_resources"
	"voice-platform/backend/internal/load/record_results"
	"voice-platform/backend/internal/load/validate_target"
)

func (r *Runner) Run(parent context.Context) (report Report) {
	started := time.Now()
	report = Report{SchemaVersion: 1, Commit: r.Manifest.Commit, Outcome: "FAIL", StopReason: "preflight", Media: "NOT_RUN: API logical leases are not LiveKit ICE-active participants or RTP load", Cleanup: "NOT_RUN"}
	r.results = record_results.New()
	defer func() {
		report.Routes = r.results.Snapshot()
		report.Requests = r.budget.Load()
		report.ElapsedSeconds = time.Since(started).Seconds()
		report.Resources = r.resources
		report.GuardFailure = r.guardFailure
		report.Criteria = criteria(report.Routes)
		finalize(&report)
	}()
	if err := r.Manifest.Validate(); err != nil {
		return report
	}
	if !validProfile(r.Profile) {
		return report
	}
	ctx, cancel := context.WithTimeout(parent, time.Duration(r.Manifest.MaxSeconds)*time.Second)
	defer cancel()
	guard := observe_resources.Guard{Manifest: r.Manifest, Client: validate_target.Client()}
	if _, err := guard.Check(ctx); err != nil {
		report.StopReason = "guard_preflight"
		r.guardFailure = observe_resources.Category(err)
		return report
	}
	stop := make(chan string, 1)
	done := make(chan struct{})
	go func() { defer close(done); r.monitor(ctx, guard, stop, cancel) }()
	defer func() { cancel(); <-done }()
	defer func() { report.Cleanup = r.cleanup(guard) }()
	if r.Profile == "nat_auth" {
		a := exercise_actor.New(r.Manifest, 0, r.results, &r.budget)
		r.actors = append(r.actors, a)
		if a.SharedNAT(ctx) != nil {
			report.StopReason = "shared_nat_quota"
			return report
		}
		report.Phases = []Phase{{Name: "shared_nat_auth", Active: 1, Seconds: time.Since(started).Seconds()}}
		report.Outcome = "PASS"
		report.StopReason = "expected_429_quota"
		return report
	}
	names := []string{"warmup", "ramp", "steady", "spike", "recovery", "saturation_stop"}
	weights := []float64{.10, .20, .30, .10, .20, .10}
	for index, name := range names {
		target := len(r.Manifest.Accounts)
		if index == 0 {
			target = 1
		}
		if index == 1 {
			target = (target + 1) / 2
		}
		if err := r.admit(ctx, target); err != nil {
			report.StopReason = "actor_admission"
			select {
			case report.StopReason = <-stop:
			default:
			}
			return report
		}
		phase, err := r.phase(ctx, guard, name, time.Duration(float64(r.Manifest.MaxSeconds)*.75*weights[index]*float64(time.Second)))
		report.Phases = append(report.Phases, phase)
		if err != nil {
			report.StopReason = "phase_operation"
			select {
			case report.StopReason = <-stop:
			default:
			}
			return report
		}
	}
	report.Outcome = "PASS"
	report.StopReason = "bounded_profile_complete"
	return report
}
