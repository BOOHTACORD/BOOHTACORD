package notificationroutes

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/app/lifecycle"
	config "voice-platform/backend/internal/config/runtime"
	cleanup "voice-platform/backend/internal/notifications/cleanup_delivery"
	control "voice-platform/backend/internal/notifications/control_delivery"
	dispatch "voice-platform/backend/internal/notifications/dispatch_delivery"
	worker "voice-platform/backend/internal/notifications/dispatch_delivery/worker"
	observe "voice-platform/backend/internal/notifications/observe_delivery"
	plan "voice-platform/backend/internal/notifications/plan_delivery"
	hints "voice-platform/backend/internal/notifications/publish_hint"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	relay "voice-platform/backend/internal/notifications/relay_sender"
	webpush "voice-platform/backend/internal/notifications/web_push"
	hub "voice-platform/backend/internal/realtime/event_hub"
)

func StartDelivery(ctx context.Context, database *pgxpool.Pool, c config.Config, events *hub.Hub, telemetry *observe.Runtime) (lifecycle.Stop, error) {
	feature := deviceConfiguration(database, c)
	// Missing transport secrets cannot enable outbox production accidentally.
	if err := control.New(database).Configure(ctx, c.NotificationsAvailable && (feature.webReady || feature.mobileReady)); err != nil {
		return nil, err
	}
	transports := map[string]dispatch.Transport{}
	if feature.mobileReady {
		public, _ := base64.RawURLEncoding.Strict().DecodeString(c.Notifications.RelayPublicKey)
		sender, err := relay.New(relay.Config{Origin: c.Notifications.RelayOrigin, Namespace: c.Notifications.Namespace, InstallationID: feature.installation, ServerOrigin: c.PublicOrigin, InstallationPrivateKey: feature.signing, RelayPublicKey: ed25519.PublicKey(public)})
		if err == nil {
			transports["mobile_relay"] = sender
		}
	}
	if feature.webReady {
		sender, err := webpush.NewSender(*feature.gate, c.Notifications.VAPIDPublicKey, feature.vapidPrivate, c.Notifications.VAPIDContact)
		if err == nil {
			transports["web_push"] = sender
		}
	}
	w := worker.Start(ctx, worker.Config{Telemetry: telemetry, Planner: plan.New(database), Dispatch: dispatch.New(database), Scope: reader.Scope{Origin: c.PublicOrigin, InstallationID: feature.installation, Namespace: c.Notifications.Namespace}, Box: feature.box, Transports: transports, Maintenance: cleanup.New(database).Run, Hints: (hints.Publisher{Database: database, Events: events}).Run})
	return w.Stop, nil
}
