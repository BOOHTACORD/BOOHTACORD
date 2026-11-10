package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"syscall"

	"voice-platform/backend/internal/load/run_roster_matrix"
	"voice-platform/backend/internal/load/validate_target"
)

func main() {
	mode := flag.String("mode", "candidate", "candidate or baseline")
	guests := flag.Int("guests", 0, "public clients from one source; 0 selects authenticated actors")
	sameSource := flag.Bool("same-source", false, "exactly 20 independent authenticated sessions from one loopback source")
	maintenanceChange := flag.Bool("maintenance-change", false, "measure a guarded maintenance activation")
	messages := flag.Int("messages", 0, "bounded synthetic messages sent over the existing fixture sockets")
	warmup := flag.Int("message-warmup-ms", 0, "bounded pause after initial snapshots before messages")
	flag.Parse()
	if *guests != 0 && (*sameSource || *maintenanceChange || *messages != 0 || *warmup != 0) {
		fmt.Fprintln(os.Stderr, "incompatible fixture profiles")
		os.Exit(2)
	}
	var manifest validate_target.Manifest
	decoder := json.NewDecoder(io.LimitReader(os.Stdin, 1<<20))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&manifest) != nil {
		fmt.Fprintln(os.Stderr, "invalid private fixture input")
		os.Exit(2)
	}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	if *guests != 0 {
		report := runrostermatrix.RunPublic(ctx, manifest, *mode, *guests)
		_ = json.NewEncoder(os.Stdout).Encode(report)
		if report.Outcome != "PASS" {
			os.Exit(1)
		}
	} else {
		report := runrostermatrix.RunWithWarmup(ctx, manifest, *mode, *sameSource, *maintenanceChange, *messages, *warmup)
		_ = json.NewEncoder(os.Stdout).Encode(report)
		if report.Outcome != "PASS" {
			os.Exit(1)
		}
	}
}
