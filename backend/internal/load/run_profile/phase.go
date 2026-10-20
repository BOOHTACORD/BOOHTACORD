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
	timer := time.NewTimer(duration)
	defer timer.Stop()
	if r.Profile == "faults" {
		faults := map[string]string{"warmup": "db_pressure", "ramp": "sfu_outage", "steady": "slow_telemetry", "spike": "disk_pressure"}
		if fault := faults[name]; fault != "" {
			if err := guard.Fault(ctx, fault); err != nil {
				return phase, err
			}
		}
	}
	if name == "recovery" {
		if err := guard.Fault(ctx, "restore"); err != nil {
			return phase, err
		}
	}
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
		for index, actor := range r.actors {
			group.Add(1)
			go func(index int) {
				defer group.Done()
				a := r.actors[index]
				var err error
				if r.Profile == "reconnect" && name == "spike" {
					err = a.Reconnect(ctx)
				} else {
					err = a.Read(ctx)
					if err == nil {
						err = a.Message(ctx, r.actors, nil)
					}
				}
				if err == nil && iteration == 0 {
					err = a.ACL(ctx)
				}
				if err == nil && r.Profile == "uploads" && (name == "steady" || name == "spike") && index < 4 && iteration == 0 {
					err = a.Upload(ctx, r.actors)
					if err == nil && index == 0 {
						err = a.UploadLimit(ctx)
					}
				}
				if err != nil {
					failures <- err
				}
			}(index)
			_ = actor
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
