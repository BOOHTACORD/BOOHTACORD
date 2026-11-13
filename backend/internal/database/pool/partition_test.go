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

func TestPartitionKeepsTotalConnectionBudgetAndMinimums(t *testing.T) {
	for _, tc := range []struct{ total, main, session int32 }{{1, 1, 0}, {2, 1, 1}, {4, 3, 1}, {20, 16, 4}, {50, 46, 4}} {
		config, err := pgxpool.ParseConfig("postgres://qa@127.0.0.1:1/qa")
		if err != nil {
			t.Fatal(err)
		}
		config.MaxConns, config.MinConns, config.MinIdleConns = tc.total, tc.total, tc.total
		main, session := partitionConfigs(config)
		if main.MaxConns != tc.main || config.MaxConns != tc.total {
			t.Fatalf("main or original changed for %d", tc.total)
		}
		if tc.session == 0 {
			if session != nil || main.MinConns != tc.total || main.MinIdleConns != tc.total {
				t.Fatal("single connection must stay shared")
			}
			continue
		}
		if session.MaxConns != tc.session || main.MinConns+session.MinConns != tc.total || main.MinIdleConns+session.MinIdleConns != tc.total {
			t.Fatalf("connection budget or minimums changed for %d", tc.total)
		}
	}
}

func TestPartitionedMetricsReportCombinedCapacity(t *testing.T) {
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
	if !strings.Contains(response.Body.String(), "voice_platform_database_pool_max 20") {
		t.Fatal("combined pool budget is missing from metrics")
	}
}
