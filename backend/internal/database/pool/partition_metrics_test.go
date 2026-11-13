package pool

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func TestPoolPartitionsExposeBoundedCapacity(t *testing.T) {
	config, err := pgxpool.ParseConfig("postgres://qa@127.0.0.1:1/qa")
	if err != nil {
		t.Fatal(err)
	}
	config.MaxConns = 20
	mainConfig, sessionConfig := partitionConfigs(config)
	main, err := pgxpool.NewWithConfig(context.Background(), mainConfig)
	if err != nil {
		t.Fatal(err)
	}
	defer main.Close()
	session, err := pgxpool.NewWithConfig(context.Background(), sessionConfig)
	if err != nil {
		t.Fatal(err)
	}
	defer session.Close()
	metrics := NewMetrics()
	metrics.pool, metrics.sessionPool = main, session
	registry := prometheus.NewRegistry()
	registry.MustRegister(metrics)
	response := httptest.NewRecorder()
	promhttp.HandlerFor(registry, promhttp.HandlerOpts{}).ServeHTTP(response, httptest.NewRequest("GET", "/", nil))
	body := response.Body.String()
	for _, want := range []string{
		`voice_platform_database_partition_connections{partition="main",state="max"} 16`,
		`voice_platform_database_partition_connections{partition="session",state="max"} 4`,
		`voice_platform_database_pool_max 20`,
	} {
		if !strings.Contains(body, want) {
			t.Fatalf("missing partition metric %q", want)
		}
	}
	if strings.Contains(body, "127.0.0.1") || strings.Contains(body, "qa") {
		t.Fatal("connection identity leaked into metrics")
	}
	metrics.sessionPool = nil
	shared := httptest.NewRecorder()
	promhttp.HandlerFor(registry, promhttp.HandlerOpts{}).ServeHTTP(shared, httptest.NewRequest("GET", "/", nil))
	if !strings.Contains(shared.Body.String(), `voice_platform_database_partition_connections{partition="shared",state="max"} 16`) || strings.Contains(shared.Body.String(), `partition="session"`) {
		t.Fatal("single-pool metrics must report only the shared partition")
	}
}
