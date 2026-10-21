package main

import (
	"context"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
	gateway "voice-platform/backend/internal/observability/central_gateway"
)

func main() {
	if run() != nil {
		fmt.Fprintln(os.Stderr, "central telemetry gateway stopped; check private registry and configuration")
		os.Exit(1)
	}
}
func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	db, err := pgxpool.New(ctx, os.Getenv("TELEMETRY_REGISTRY_DATABASE_URL"))
	if err != nil {
		return err
	}
	defer db.Close()
	store := gateway.Postgres{DB: db}
	if err = store.Initialize(ctx); err != nil {
		return err
	}
	key, err := os.ReadFile(os.Getenv("TELEMETRY_CREDENTIAL_KEY_FILE"))
	if err != nil {
		return err
	}
	read, err := os.ReadFile(os.Getenv("TELEMETRY_READ_TOKEN_FILE"))
	if err != nil {
		return err
	}
	if len(strings.TrimSpace(string(read))) < 32 {
		return errors.New("read credential too short")
	}
	handler, err := gateway.New(gateway.Config{Registry: store, CredentialKey: key, ReadToken: strings.TrimSpace(string(read)), TempoURL: os.Getenv("TELEMETRY_TEMPO_URL"), TempoQueryURL: os.Getenv("TELEMETRY_TEMPO_QUERY_URL"), MetricsURL: os.Getenv("TELEMETRY_METRICS_URL")})
	if err != nil {
		return err
	}
	address := os.Getenv("TELEMETRY_GATEWAY_ADDR")
	if address == "" {
		address = ":8081"
	}
	server := &http.Server{Addr: address, Handler: handler, ReadHeaderTimeout: 3 * time.Second, ReadTimeout: 5 * time.Second, WriteTimeout: 8 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 8192}
	go func() {
		<-ctx.Done()
		closeCtx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()
		_ = server.Shutdown(closeCtx)
	}()
	err = server.ListenAndServe()
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}
