package run_profile

import (
	"context"
	"sync"
	"sync/atomic"
	"time"
	"voice-platform/backend/internal/load/exercise_actor"
	"voice-platform/backend/internal/load/observe_resources"
	"voice-platform/backend/internal/load/record_results"
	"voice-platform/backend/internal/load/validate_target"
)

type Phase struct {
	Name              string
	Failure           string
	Active            int
	Seconds           float64
	Errors            int
	CadenceMS         int64
	Requests          int64
	RequestsPerSecond float64
}
type Report struct {
	SchemaVersion       int
	Commit              string
	Requests            int64
	ElapsedSeconds      float64
	Outcome, StopReason string
	GuardFailure        string
	Phases              []Phase
	Routes              map[string]record_results.Summary
	Resources           []observe_resources.Snapshot
	Criteria            map[string]string
	Media               string
	Cleanup             string
}
type Runner struct {
	Manifest     validate_target.Manifest
	Profile      string
	results      *record_results.Results
	budget       atomic.Int64
	actors       []*exercise_actor.Actor
	mu           sync.Mutex
	resources    []observe_resources.Snapshot
	guardFailure string
}

func (r *Runner) cleanup(guard observe_resources.Guard) string {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	outcome := "PASS"
	if guard.Fault(ctx, "restore") != nil {
		outcome = "FAIL"
	}
	var group sync.WaitGroup
	failures := make(chan error, len(r.actors))
	for _, actor := range r.actors {
		group.Add(1)
		go func(a *exercise_actor.Actor) {
			defer group.Done()
			if err := a.Stop(ctx); err != nil {
				failures <- err
			}
		}(actor)
	}
	group.Wait()
	close(failures)
	for range failures {
		outcome = "FAIL"
	}
	return outcome
}
