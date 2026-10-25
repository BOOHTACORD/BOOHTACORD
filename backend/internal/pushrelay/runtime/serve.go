package relayruntime

import (
	"context"
	"errors"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"net/http"
	"time"
	"voice-platform/backend/internal/app/lifecycle"
)

func serve(parent context.Context, handler http.Handler, registry *prometheus.Registry, c Config) error {
	ctx, stop := context.WithCancel(parent)
	defer stop()
	makeServer := func(address string, h http.Handler) *http.Server {
		return &http.Server{Addr: address, Handler: h, ReadHeaderTimeout: 3 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 15 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 16384}
	}
	servers := []*http.Server{makeServer(c.Address, handler), makeServer(c.MetricsAddress, promhttp.HandlerFor(registry, promhttp.HandlerOpts{}))}
	finished := make(chan error, 2)
	for _, server := range servers {
		go func() { finished <- lifecycle.Serve(ctx, server) }()
	}
	received := 0
	var result error
	select {
	case result = <-finished:
		received++
	case <-parent.Done():
	}
	stop()
	deadline := time.NewTimer(12 * time.Second)
	defer deadline.Stop()
	for received < 2 {
		select {
		case err := <-finished:
			result = errors.Join(result, err)
			received++
		case <-deadline.C:
			for _, server := range servers {
				_ = server.Close()
			}
			return errors.New("relay shutdown deadline")
		}
	}
	return result
}
