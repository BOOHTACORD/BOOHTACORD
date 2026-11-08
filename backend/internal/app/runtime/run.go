// Package app is the API composition entrypoint. Domain packages own behavior.
package app

import (
	"context"
	"errors"
	"go.opentelemetry.io/otel"
	"log/slog"
	"net/http"
	"os"
	"time"
	"voice-platform/backend/internal/app/lifecycle"
	screenviewerpresenceapp "voice-platform/backend/internal/app/media_routes/screen_viewer_presence"
	"voice-platform/backend/internal/app/telemetry"
	workerruntime "voice-platform/backend/internal/app/worker_runtime"
	clientupdates "voice-platform/backend/internal/client_updates/catalog"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	"voice-platform/backend/internal/database/pool"
	observeusage "voice-platform/backend/internal/identity/observe_usage"
	previewmemory "voice-platform/backend/internal/media/screen_preview/memory"
	presencememory "voice-platform/backend/internal/media/screen_viewer_presence/memory"
	centralexport "voice-platform/backend/internal/observability/central_export"
	installation "voice-platform/backend/internal/observability/installation"
	dependencies "voice-platform/backend/internal/observability/observe_dependencies"
	writerlock "voice-platform/backend/internal/storage/acquire_writer_lock"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
)

func Run(ctx context.Context) (result error) {
	configuration, err := runtimeconfig.Load(os.Getenv)
	if err != nil {
		return err
	}
	resources := lifecycle.Stack{}
	defer func() {
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		result = errors.Join(result, resources.Close(shutdown))
	}()
	writer, err := writerlock.Acquire(configuration.AttachmentRoot)
	if err != nil {
		return err
	}
	resources.Add(func(context.Context) error { return writer.Close() })
	metrics, poolMetrics, err := configureMetrics(configuration)
	if err != nil {
		return err
	}
	database, err := pool.OpenObserved(ctx, configuration.DatabaseURL, poolMetrics)
	if err != nil {
		return err
	}
	resources.Add(func(ctx context.Context) error { return lifecycle.Wait(ctx, database.Close) })
	identity, identityErr := installation.Load(ctx, database)
	if identityErr != nil {
		slog.Warn("installation identity unavailable; external telemetry disabled")
	}
	central := centralexport.New(identity, func(c context.Context) (installation.Identity, error) { return installation.Load(c, database) }, func(c context.Context, i installation.Identity) error { return installation.Save(c, database, i) })
	central.RecordAcceptance = func(c context.Context, i installation.Identity, at time.Time) error {
		return installation.Confirm(c, database, i, at)
	}
	configuration.CentralTelemetry = central
	configuration.CausalKey = identity.ProofKey()
	resources.Add(central.Start(ctx))
	ctx = centralexport.Context(ctx, central)
	stopTelemetry, err := telemetry.Start(ctx)
	if err != nil {
		slog.Warn("telemetry provider unavailable; application continues")
	} else {
		resources.Add(stopTelemetry)
	}
	if identityErr == nil {
		slog.SetDefault(slog.Default().With("installation_id", identity.ID, "service_instance_id", central.Instance()))
	}
	resources.Add(func(context.Context) error { return poolMetrics.StopExport() })
	usageStore := observeusage.NewPostgres(database)
	usage := observeusage.NewTracker(usageStore, time.Now)
	previews := previewmemory.New()
	resources.Add(func(context.Context) error { return previews.Close() })
	stopUsage, err := observeusage.RegisterMetrics(otel.Meter("boohtacord/user-usage"), usageStore, usage, time.Now)
	if err != nil {
		return err
	}
	resources.Add(func(context.Context) error { return stopUsage() })
	events, stopRealtime := workerruntime.StartRealtime(ctx, database)
	resources.Add(stopRealtime)
	screenViewers := presencememory.New(screenviewerpresenceapp.NewHints(events).Changed)
	resources.Add(func(context.Context) error { return screenViewers.Close() })
	updates := clientupdates.NewStore(configuration.ClientUpdateCatalogPath, configuration.ClientUpdateAllowedHosts, metrics)
	updates.Start(ctx)
	publicHandler, maintenanceObserver, stopPublic, err := startPublicRealtime(ctx, database, configuration)
	if err != nil {
		return err
	}
	resources.Add(stopPublic)
	handler, screenPreviewService, err := routes(ctx, &resources, database, configuration, events, metrics, updates, usage, previews, screenViewers, publicHandler, maintenanceObserver)
	if err != nil {
		return err
	}
	resources.Add(screenPreviewService.Start(ctx))
	startSupport(ctx, database, configuration.AttachmentRoot, events, &resources)
	space, err := reserve.NewFilesystem(configuration.AttachmentRoot)
	if err != nil {
		return err
	}
	resources.Add(dependencies.Start(ctx, configuration.MediaSnapshot, space).Stop)
	resources.Add(workerruntime.StartVoice(ctx, database, configuration, metrics, events))
	if err := startNotifications(ctx, database, configuration, events, metrics, &resources); err != nil {
		return err
	}
	server := &http.Server{Addr: configuration.Address, Handler: handler, ReadHeaderTimeout: 5 * time.Second}
	slog.Info("api listening", "address", configuration.Address)
	return lifecycle.Serve(ctx, server)
}
