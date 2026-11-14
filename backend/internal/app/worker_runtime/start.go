package workerruntime

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"voice-platform/backend/internal/app/lifecycle"
	finalizationworker "voice-platform/backend/internal/channel/finalize_closed_voice_channel/worker"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	"voice-platform/backend/internal/lifecycle/periodic"
	dispatchvoicesfurevocation "voice-platform/backend/internal/media/dispatch_voice_sfu_revocation"
	sfurevocationworker "voice-platform/backend/internal/media/dispatch_voice_sfu_revocation/worker"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	replayeventpostgres "voice-platform/backend/internal/realtime/replay_event/postgres"
	notifyleaserevocation "voice-platform/backend/internal/voice/notify_lease_revocation"
	notificationworker "voice-platform/backend/internal/voice/notify_lease_revocation/worker"
	afkrouting "voice-platform/backend/internal/voice/route_inactive_members"
	afkroutingworker "voice-platform/backend/internal/voice/route_inactive_members/worker"
)

func StartRealtime(ctx context.Context, database *pgxpool.Pool) (*eventhub.Hub, lifecycle.Stop) {
	events := eventhub.New(64)
	events.SetJournal(replayeventpostgres.New(database))
	service := notifyleaserevocation.New(
		notifyleaserevocation.NewRepository(notifyleaserevocation.NewPoolDatabase(database)), events)
	worker := notificationworker.Start(ctx, service)
	idlePresence := periodic.Start(ctx, 15*time.Second, func(context.Context) { events.SweepIdle(time.Now(), eventhub.DefaultIdleAfter) })
	return events, func(ctx context.Context) error {
		return errors.Join(worker.Stop(ctx), idlePresence.Stop(ctx))
	}
}

func StartVoice(ctx context.Context, database *pgxpool.Pool, configuration runtimeconfig.Config, metrics *httpmetrics.Recorder, events *eventhub.Hub) lifecycle.Stop {
	sfu := sfurevocationworker.Start(ctx, dispatchvoicesfurevocation.New(
		dispatchvoicesfurevocation.NewRepository(dispatchvoicesfurevocation.NewPoolDatabase(database)), configuration.RoomRemover,
	), metrics)
	finalization := finalizationworker.Start(ctx, finalizationworker.NewService(database, configuration.MediaSnapshot, events))
	afk := afkroutingworker.Start(ctx, afkrouting.New(database, events))
	return func(ctx context.Context) error {
		return errors.Join(finalization.Stop(ctx), sfu.Stop(ctx), afk.Stop(ctx))
	}
}
