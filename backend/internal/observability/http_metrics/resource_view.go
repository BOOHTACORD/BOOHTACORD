package httpmetrics

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// The existing metrics route can expose its resource subset without waiting
// for dependency-backed collectors. It never exposes additional metrics.
func resourceView(all, resources *prometheus.Registry) http.Handler {
	full := promhttp.HandlerFor(all, promhttp.HandlerOpts{})
	limited := promhttp.HandlerFor(resources, promhttp.HandlerOpts{})
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("view") == "resources" {
			limited.ServeHTTP(w, r)
			return
		}
		full.ServeHTTP(w, r)
	})
}
