package run_profile

import (
	"context"
	"voice-platform/backend/internal/load/exercise_actor"
)

func recoverFaultSocket(ctx context.Context, profile string, actor *exercise_actor.Actor) error {
	if profile == "faults" && actor.Socket.Failed() {
		return actor.Reconnect(ctx)
	}
	return nil
}
