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
	notificationroutes "voice-platform/backend/internal/app/notification_routes"
	"voice-platform/backend/internal/app/telemetry"
	workerruntime "voice-platform/backend/internal/app/worker_runtime"
	clientupdates "voice-platform/backend/internal/client_updates/catalog"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	"voice-platform/backend/internal/database/pool"
	admitlogin "voice-platform/backend/internal/identity/admit_login"
	observeusage "voice-platform/backend/internal/identity/observe_usage"
	"voice-platform/backend/internal/identity/password"
	previewmemory "voice-platform/backend/internal/media/screen_preview/memory"
	presencememory "voice-platform/backend/internal/media/screen_viewer_presence/memory"
	centralexport "voice-platform/backend/internal/observability/central_export"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
 notificationmetrics "voice-platform/backend/internal/notifications/observe_delivery"
	installation "voice-platform/backend/internal/observability/installation"
	dependencies "voice-platform/backend/internal/observability/observe_dependencies"
	ratelimit "voice-platform/backend/internal/security/rate_limit"
	writerlock "voice-platform/backend/internal/storage/acquire_writer_lock"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
	supportbridge "voice-platform/backend/internal/support/bridge"
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
	metrics := httpmetrics.New()
	if err := metrics.RegisterCollector(ratelimit.NewCollector(map[string]*ratelimit.Limiter{
		"registration": configuration.RegistrationLimiter, "login_source": configuration.LoginLimiter,
		"password_reset": configuration.PasswordResetLimiter,
		"upload_source":  configuration.UploadLimiter, "upload_account": configuration.UploadAccountLimiter,
		"upload_deployment": configuration.UploadDeploymentLimiter, "telemetry": configuration.TelemetryLimiter,
	})); err != nil {
		return err
	}
	poolMetrics := pool.NewMetrics()
	if err := metrics.RegisterCollector(admitlogin.NewCollector(configuration.LoginAdmission)); err != nil {
		return err
	}
	if err := metrics.RegisterCollector(password.NewCollector()); err != nil {
		return err
	}
	if err := metrics.RegisterCollector(poolMetrics); err != nil {
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
	handler, err := routes(database, configuration, events, metrics, updates, usage, previews, screenViewers)
	if err != nil {
		return err
	}
	// Storage route composition has now created the same private file directory used by downloads.
	supportWorker, supportErr := supportbridge.NewWorker(ctx, database, configuration.AttachmentRoot, os.Getenv("PRODUCT_SUPPORT_ENDPOINT"), events)
	if supportErr != nil {
		slog.Warn("product support worker unavailable")
	} else {
		resources.Add(supportWorker.Start(ctx))
	}
	space, err := reserve.NewFilesystem(configuration.AttachmentRoot)
	if err != nil {
		return err
	}
	resources.Add(dependencies.Start(ctx, configuration.MediaSnapshot, space).Stop)
	resources.Add(workerruntime.StartVoice(ctx, database, configuration, metrics, events))
	notificationTelemetry := notificationmetrics.NewRuntime()
 if err := metrics.RegisterCollector(notificationmetrics.NewCollector(database));err!=nil{return err}
 if err := metrics.RegisterCollector(notificationTelemetry);err!=nil{return err}
 stopNotifications, err := notificationroutes.StartDelivery(ctx, database, configuration, events, notificationTelemetry)
	if err != nil {
		return err
	}
	resources.Add(stopNotifications)
	server := &http.Server{Addr: configuration.Address, Handler: handler, ReadHeaderTimeout: 5 * time.Second}
	slog.Info("api listening", "address", configuration.Address)
	return lifecycle.Serve(ctx, server)
}
