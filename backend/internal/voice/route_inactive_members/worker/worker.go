package worker

import (
	"context"
	"log/slog"
	"time"

	"voice-platform/backend/internal/lifecycle/periodic"
)

type Router interface {
	RouteInactive(context.Context) (int, error)
}

func Start(parent context.Context, router Router) *periodic.Worker {
	return periodic.Start(parent, 15*time.Second, func(ctx context.Context) {
		work, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		moved, err := router.RouteInactive(work)
		if err != nil {
			slog.Warn("AFK voice routing did not complete")
		}
		_ = moved
	})
}
