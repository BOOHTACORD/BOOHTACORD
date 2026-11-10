package app

import (
	"context"
	"log/slog"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/app/lifecycle"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	supportbridge "voice-platform/backend/internal/support/bridge"
)

func startSupport(ctx context.Context, database *pgxpool.Pool, root string, events *eventhub.Hub, resources *lifecycle.Stack) {
	// Route composition has created the private attachment directory.
	worker, err := supportbridge.NewWorker(ctx, database, root, os.Getenv("PRODUCT_SUPPORT_ENDPOINT"), events)
	if err != nil {
		slog.Warn("product support worker unavailable")
	} else {
		resources.Add(worker.Start(ctx))
	}
}
