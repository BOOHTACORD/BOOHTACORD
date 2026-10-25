package relayruntime

import (
	"context"
	"crypto/ed25519"
	"errors"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
	"time"
	"voice-platform/backend/internal/app/lifecycle"
	keys "voice-platform/backend/internal/notifications/load_keys"
	"voice-platform/backend/internal/notifications/secretbox"
	accept "voice-platform/backend/internal/pushrelay/accept_notification"
	control "voice-platform/backend/internal/pushrelay/control_queue"
	dispatch "voice-platform/backend/internal/pushrelay/dispatch_job"
	worker "voice-platform/backend/internal/pushrelay/dispatch_job/worker"
	enroll "voice-platform/backend/internal/pushrelay/enroll_device"
	provider "voice-platform/backend/internal/pushrelay/fcm_provider"
	api "voice-platform/backend/internal/pushrelay/http_api"
	observe "voice-platform/backend/internal/pushrelay/observe_queue"
	pair "voice-platform/backend/internal/pushrelay/pair_installation"
	revoke "voice-platform/backend/internal/pushrelay/revoke_grant"
	schema "voice-platform/backend/internal/pushrelay/schema"
	rate "voice-platform/backend/internal/security/rate_limit"
)

func Run(ctx context.Context, c Config, action string) error {
	configuration, err := pgxpool.ParseConfig(c.DatabaseURL)
	if err != nil {
		return ErrConfiguration
	}
	configuration.MaxConns = 8
	configuration.MinConns = 1
	configuration.ConnConfig.ConnectTimeout = 5 * time.Second
	database, err := pgxpool.NewWithConfig(ctx, configuration)
	if err != nil {
		return errors.New("relay database unavailable")
	}
	defer database.Close()
	setup, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	if err = schema.Migrate(setup, database); err != nil {
		return errors.New("relay schema unavailable")
	}
	if err = schema.BindNamespace(setup, database, c.Namespace); err != nil {
		return errors.New("relay namespace mismatch")
	}
	controller := control.Store{Database: database}
	if action == "kill" {
		return controller.Kill(setup, true)
	}
	if action == "resume" {
		return controller.Kill(setup, false)
	}
	var box *secretbox.Box
	var signing ed25519.PrivateKey
	if raw, e := keys.Load32(c.SecretFile); e == nil {
		box, _ = secretbox.New(raw)
	}
	if raw, e := keys.Load32(c.SigningFile); e == nil {
		signing = ed25519.NewKeyFromSeed(raw)
	}
	sender, providerErr := provider.New(c.FCMFile, c.FCMProject)
	ready := c.Enabled && (c.AndroidEnabled || c.IOSEnabled) && box != nil && len(signing) == ed25519.PrivateKeySize && providerErr == nil
	if err = controller.Configure(setup, ready); err != nil {
		return errors.New("relay policy unavailable")
	}
	if err = controller.Platforms(setup, c.AndroidEnabled, c.IOSEnabled); err != nil {
		return errors.New("relay platform policy unavailable")
	}
	ctx, stop := context.WithCancel(ctx)
	defer stop()
	var resources lifecycle.Stack
	defer func() {
		end, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()
		_ = resources.Close(end)
	}()
	resources.Add(startMaintenance(ctx, controller))
	if ready {
		resources.Add(worker.Start(ctx, dispatch.Store{Database: database, Box: box, Namespace: c.Namespace, Platforms: map[string]bool{"android": c.AndroidEnabled, "ios": c.IOSEnabled}}, sender).Stop)
	}
	limiter, _ := rate.New(rate.Config{Limit: 600, Window: time.Minute, MaxSources: 1024})
	handler := api.Handler{Ready: ready, Limiter: limiter, Health: database.Ping, Enroll: enroll.Service{Database: database, Box: box, Namespace: c.Namespace, Platforms: map[string]bool{"android": c.AndroidEnabled, "ios": c.IOSEnabled}}, Pair: pair.Service{Database: database, SigningKey: signing, Namespace: c.Namespace}, Accept: accept.Service{Database: database, Box: box, Namespace: c.Namespace, Platforms: map[string]bool{"android": c.AndroidEnabled, "ios": c.IOSEnabled}}, Revoke: revoke.Store{Database: database}}
	registry := prometheus.NewRegistry()
	if err = registry.Register(observe.New(database, c.Namespace)); err != nil {
		return errors.New("relay metrics unavailable")
	}
	return serve(ctx, handler.Routes(), registry, c)
}
