package main

import (
	"context"
	"flag"
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
	"os"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
)

func main() {
	kill := flag.Bool("kill", false, "Stop new sends and quarantine pending notifications")
	resume := flag.Bool("resume", false, "Allow new opt-in notifications; quarantined work stays terminal")
	flag.Parse()
	if *kill == *resume || flag.NArg() != 0 {
		fmt.Fprintln(os.Stderr, "usage: notification-control --kill|--resume")
		os.Exit(2)
	}
	if err := apply(*kill); err != nil {
		fmt.Fprintln(os.Stderr, "notification control failed; verify private database access and schema")
		os.Exit(1)
	}
	fmt.Println("Notification sending policy updated. Existing provider acceptance cannot be recalled.")
}
func apply(kill bool) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	config, err := pgxpool.ParseConfig(os.Getenv("DATABASE_URL"))
	if err != nil {
		return err
	}
	config.MaxConns = 1
	config.MinConns = 0
	config.ConnConfig.ConnectTimeout = 3 * time.Second
	database, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return err
	}
	defer database.Close()
	return control.New(database).Kill(ctx, kill)
}
