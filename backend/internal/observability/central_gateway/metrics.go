package centralgateway

import (
	"context"
	"fmt"
	"net/http"
	"time"
)

// The central reverse proxy publishes only /v1/*; this private registry scrape
// is owner-only, just like Prometheus and the datasource read gateway.
func (g *Gateway) metrics(w http.ResponseWriter, r *http.Request) {
	lister, ok := g.config.Registry.(interface {
		List(context.Context) ([]Record, error)
	})
	if !ok {
		w.WriteHeader(503)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	rows, err := lister.List(ctx)
	if err != nil {
		w.WriteHeader(503)
		return
	}
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	for _, row := range rows {
		seen := float64(0)
		if row.LastSeen != nil {
			seen = float64(row.LastSeen.Unix())
		}
		enabled := 0
		if row.Enabled {
			enabled = 1
		}
		disabled := 0
		if row.Mode == "disabled" {
			disabled = 1
		}
		fmt.Fprintf(w, "boohtacord_installation_registered{installation_id=%q} 1\nboohtacord_installation_enabled{installation_id=%q} %d\nboohtacord_installation_export_disabled{installation_id=%q} %d\nboohtacord_installation_last_seen_seconds{installation_id=%q} %.0f\n", row.ID, row.ID, enabled, row.ID, disabled, row.ID, seen)
	}
}
