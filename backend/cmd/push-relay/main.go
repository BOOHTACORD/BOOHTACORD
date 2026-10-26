package main

import (
	"context"
	"flag"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	runtime "voice-platform/backend/internal/pushrelay/runtime"
)

func main() {
	kill := flag.Bool("kill", false, "Persistently stop sending and quarantine pending jobs")
	resume := flag.Bool("resume", false, "Resume new sending without replaying quarantined jobs")
	flag.Parse()
	if *kill && *resume {
		slog.Error("choose one relay control action")
		os.Exit(2)
	}
	configuration, err := runtime.Load(os.Getenv)
	if err != nil {
		slog.Error("relay configuration invalid")
		os.Exit(2)
	}
	action := ""
	if *kill {
		action = "kill"
	}
	if *resume {
		action = "resume"
	}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	if runtime.Run(ctx, configuration, action) != nil {
		slog.Error("relay stopped; inspect database availability, namespace and configuration")
		os.Exit(1)
	}
}
