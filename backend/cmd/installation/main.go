// installation is an offline operator tool. It never prints credentials or keys.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
	"os"
	"time"
	central "voice-platform/backend/internal/observability/central_export"
	identity "voice-platform/backend/internal/observability/installation"
)

func main() {
	if run() != nil {
		fmt.Fprintln(os.Stderr, "installation operation failed; inspect database readiness and explicit operator arguments")
		os.Exit(1)
	}
}
func run() error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	db, err := pgxpool.New(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		return err
	}
	defer db.Close()
	i, err := identity.Load(ctx, db)
	if err != nil {
		return err
	}
	r := central.New(i, nil, func(ctx context.Context, i identity.Identity) error { return identity.Save(ctx, db, i) })
	switch {
	case len(os.Args) == 2 && os.Args[1] == "status":
	case len(os.Args) == 3 && os.Args[1] == "agent-config":
		return agentConfig(os.Args[2], i)
	case len(os.Args) == 2 && os.Args[1] == "disable":
		err = r.Disable(ctx)
	case len(os.Args) == 3 && os.Args[1] == "enable":
		err = r.Enable(ctx, os.Args[2])
	case len(os.Args) == 3 && os.Args[1] == "reset-clone" && os.Args[2] == "--confirm-independent-clone":
		i, err = identity.ResetClone(ctx, db)
		r = central.New(i, nil, nil)
	default:
		return fmt.Errorf("expected status, disable, enable HTTPS-origin or reset-clone --confirm-independent-clone")
	}
	if err != nil {
		return err
	}
	return json.NewEncoder(os.Stdout).Encode(r.Snapshot())
}
