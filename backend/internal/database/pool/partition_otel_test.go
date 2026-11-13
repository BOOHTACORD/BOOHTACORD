package pool

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.opentelemetry.io/otel"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
)

func TestPartitionCapacityIsExportedToOpenTelemetry(t *testing.T) {
	reader := sdkmetric.NewManualReader()
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
	old := otel.GetMeterProvider()
	otel.SetMeterProvider(provider)
	defer func() { otel.SetMeterProvider(old); _ = provider.Shutdown(t.Context()) }()
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
	metrics.startExport()
	defer metrics.StopExport()
	var data metricdata.ResourceMetrics
	if err := reader.Collect(t.Context(), &data); err != nil {
		t.Fatal(err)
	}
	maximums := make(map[string]float64)
	for _, scope := range data.ScopeMetrics {
		for _, item := range scope.Metrics {
			if item.Name != "boohtacord.incident.database.pool.partition" {
				continue
			}
			gauge, ok := item.Data.(metricdata.Gauge[float64])
			if !ok {
				t.Fatal("partition metric is not a gauge")
			}
			for _, point := range gauge.DataPoints {
				partition, foundPartition := point.Attributes.Value("partition")
				stat, foundStat := point.Attributes.Value("stat")
				if foundPartition && foundStat && stat.AsString() == "max" {
					maximums[partition.AsString()] = point.Value
				}
			}
		}
	}
	if len(maximums) != 2 || maximums["main"] != 16 || maximums["session"] != 4 {
		t.Fatalf("unexpected partition maximums: %#v", maximums)
	}
}
