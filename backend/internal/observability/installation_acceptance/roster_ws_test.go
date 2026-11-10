//go:build installation_acceptance

package installationacceptance

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	migrate "voice-platform/backend/internal/database/migrate"
	central "voice-platform/backend/internal/observability/central_export"
	gateway "voice-platform/backend/internal/observability/central_gateway"
	identity "voice-platform/backend/internal/observability/installation"
	rosterws "voice-platform/backend/internal/observability/roster_ws_metrics"
	metricstart "voice-platform/backend/internal/observability/start_metrics"
)

func TestRosterWSMetricsThroughRealCentralStorage(t *testing.T) {
	base := os.Getenv("BOOHTACORD_TELEMETRY_TEST_DATABASE_URL")
	if base == "" {
		t.Skip("requires owned PostgreSQL and telemetry fixture")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Second)
	defer cancel()
	db, registryDB := ownedDatabase(t, base), ownedDatabase(t, base)
	must(t, migrate.Run(ctx, db), "migrate roster metrics database")
	installation, err := identity.Load(ctx, db)
	must(t, err, "load test installation")
	store := gateway.Postgres{DB: registryDB}
	must(t, store.Initialize(ctx), "initialize registry")
	gw, err := gateway.New(gateway.Config{Registry: store, CredentialKey: bytes.Repeat([]byte{7}, 32), ReadToken: "synthetic-private-owner-token", TempoURL: os.Getenv("BOOHTACORD_TELEMETRY_TEST_OTLP"), TempoQueryURL: os.Getenv("BOOHTACORD_TELEMETRY_TEST_TEMPO"), MetricsURL: os.Getenv("BOOHTACORD_TELEMETRY_TEST_COLLECTOR")})
	must(t, err, "compose gateway")
	server := httptest.NewTLSServer(gw)
	defer server.Close()
	client := server.Client()
	transport := client.Transport.(*http.Transport).Clone()
	transport.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
		u, _ := url.Parse(server.URL)
		return (&net.Dialer{}).DialContext(ctx, network, u.Host)
	}
	client = &http.Client{Transport: transport, Timeout: 4 * time.Second}
	u, _ := url.Parse(server.URL)
	endpoint := "https://example.com:" + u.Port()
	runtime := central.New(installation, func(ctx context.Context) (identity.Identity, error) { return identity.Load(ctx, db) }, func(ctx context.Context, i identity.Identity) error { return identity.Save(ctx, db, i) }, client)
	runtime.RecordAcceptance = func(ctx context.Context, i identity.Identity, at time.Time) error {
		return identity.Confirm(ctx, db, i, at)
	}
	must(t, runtime.Enable(ctx, endpoint), "enroll test installation")
	stop := runtime.Start(ctx)
	defer stop(context.Background())
	installation = runtime.Identity()
	t.Setenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", "")
	t.Setenv("APP_VERSION", "1.0.44")
	previous := otel.GetMeterProvider()
	defer otel.SetMeterProvider(previous)
	stopMetrics, err := metricstart.Start(central.Context(ctx, runtime))
	must(t, err, "start real metrics")
	defer stopMetrics(context.Background())
	metrics := rosterws.New(prometheus.NewRegistry())
	metrics.Open()
	metrics.Delivery(20*time.Millisecond, "unavailable", true)
	metrics.Delivery(30*time.Millisecond, "success", false)
	metrics.Refresh(true)
	publishCapabilityMetrics()
	must(t, otel.GetMeterProvider().(*sdkmetric.MeterProvider).ForceFlush(ctx), "flush roster metrics")
	query := `{__name__=~"voice_platform_voice_roster_ws_.*",installation_id="` + installation.ID + `"}`
	eventually(t, "roster WS metrics in real Prometheus", func() bool {
		response, e := http.Get(os.Getenv("BOOHTACORD_TELEMETRY_TEST_PROMETHEUS") + "/api/v1/query?query=" + url.QueryEscape(query))
		if e != nil {
			return false
		}
		defer response.Body.Close()
		raw, e := io.ReadAll(io.LimitReader(response.Body, 2<<20))
		if e != nil {
			return false
		}
		var result struct {
			Data struct {
				Result []struct {
					Metric map[string]string `json:"metric"`
				} `json:"result"`
			} `json:"data"`
		}
		if json.Unmarshal(raw, &result) != nil {
			return false
		}
		names := map[string]bool{}
		outcomes := map[string]bool{}
		for _, series := range result.Data.Result {
			name := series.Metric["__name__"]
			names[name] = true
			if name == "voice_platform_voice_roster_ws_delivery_total" {
				outcomes[series.Metric["outcome"]] = true
			}
			for key := range series.Metric {
				if strings.Contains(key, "user") || strings.Contains(key, "session") || strings.Contains(key, "channel") {
					t.Error("private label in central series")
				}
			}
		}
		return names["voice_platform_voice_roster_ws_subscribers"] && names["voice_platform_voice_roster_ws_delivery_total"] && names["voice_platform_voice_roster_ws_refresh_total"] && names["voice_platform_voice_roster_ws_last_success_timestamp_seconds"] && names["voice_platform_voice_roster_ws_observation_enabled"] && outcomes["success"] && outcomes["unavailable"]
	})
	assertCapabilityMetrics(t, installation.ID)
	metrics.Close()
}
