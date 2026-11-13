package run_profile

import (
	"context"
	"errors"
	"sync"
	"time"
	"voice-platform/backend/internal/load/observe_resources"
)

func (r *Runner) phase(ctx context.Context, guard observe_resources.Guard, name string, duration time.Duration) (phase Phase, err error) {
	started := time.Now()
	before := r.budget.Load()
	phase = Phase{Name: name, Active: len(r.actors), CadenceMS: cadence(name).Milliseconds()}
	defer func() {
		phase.Seconds = time.Since(started).Seconds()
		phase.Requests = r.budget.Load() - before
		phase.RequestsPerSecond = float64(phase.Requests) / phase.Seconds
	}()
	if r.Profile == "faults" {
		faults := map[string]string{"warmup": "db_pressure", "ramp": "sfu_outage", "steady": "slow_telemetry", "spike": "disk_pressure"}
		if fault := faults[name]; fault != "" {
			if err := guard.FaultFor(ctx, fault, duration); err != nil {
				phase.Failure = "fault_" + observe_resources.Category(err)
				if ctx.Err() != nil {
					phase.Failure = "canceled"
				}
				return phase, err
			}
			if err := guard.WaitFault(ctx, fault); err != nil {
				phase.Failure = "fault_unverified"
				return phase, err
			}
			defer func() {
				if err == nil {
					if check := guard.FaultActive(ctx, fault); check != nil {
						phase.Failure, err = "fault_lost", check
					}
				}
			}()
		}
	}
	if name == "recovery" {
		if err := guard.Fault(ctx, "restore"); err != nil {
			phase.Failure = "restore_" + observe_resources.Category(err)
			if ctx.Err() != nil {
				phase.Failure = "canceled"
			}
			return phase, err
		}
	}
	timer := time.NewTimer(duration)
	defer timer.Stop()
	workCtx, cancelWork := operationContext(ctx, r.Profile, name, duration)
	defer cancelWork()
	for iteration := 0; ; iteration++ {
		select {
		case <-ctx.Done():
			return phase, ctx.Err()
		case <-timer.C:
			phase.Seconds = time.Since(started).Seconds()
			return phase, ctx.Err()
		default:
		}
		var group sync.WaitGroup
		failures := make(chan error, len(r.actors))
		for index := range r.actors {
			group.Add(1)
			go func(index int) {
				defer group.Done()
				if err := r.exercise(ctx, workCtx, name, iteration, index); err != nil {
					failures <- err
				}
			}(index)
		}
		group.Wait()
		close(failures)
		for range failures {
			phase.Errors++
		}
		if phase.Errors > 0 && !(r.Profile == "faults" && name != "recovery" && name != "saturation_stop") {
			return phase, errors.New("load operation failed")
		}
		if phase.Errors > len(r.actors)*4 {
			return phase, errors.New("dependency fault error budget exceeded")
		}
		pause := time.NewTimer(cadence(name))
		select {
		case <-ctx.Done():
			pause.Stop()
			return phase, ctx.Err()
		case <-timer.C:
			pause.Stop()
			return phase, ctx.Err()
		case <-pause.C:
		}
	}
}
