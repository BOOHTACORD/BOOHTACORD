package app

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/app/lifecycle"
	notificationroutes "voice-platform/backend/internal/app/notification_routes"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	notificationmetrics "voice-platform/backend/internal/notifications/observe_delivery"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func startNotifications(ctx context.Context, database *pgxpool.Pool, config runtimeconfig.Config, events *eventhub.Hub, metrics *httpmetrics.Recorder, resources *lifecycle.Stack) error {
	telemetry := notificationmetrics.NewRuntime()
	if err := metrics.RegisterCollector(notificationmetrics.NewCollector(database)); err != nil {
		return err
	}
	if err := metrics.RegisterCollector(telemetry); err != nil {
		return err
	}
	stop, err := notificationroutes.StartDelivery(ctx, database, config, events, telemetry)
	if err != nil {
		return err
	}
	resources.Add(stop)
	return nil
}
