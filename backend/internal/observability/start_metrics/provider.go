package startmetrics

import (
	"context"
	"errors"
	"os"
	"time"
	centralexport "voice-platform/backend/internal/observability/central_export"
	incident "voice-platform/backend/internal/observability/observe_incidents"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
)

// Start exports only explicitly recorded instruments; existing private Prometheus metrics remain intact.
func Start(ctx context.Context) (func(context.Context) error, error) {
	configured := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") != "" || os.Getenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT") != ""
	central := centralexport.From(ctx)
	incident.Default.SetEnabled("metric_export", configured)
	if !configured && central == nil {
		return func(context.Context) error { return nil }, nil
	}
	options := []otlpmetrichttp.Option{}
	if central != nil {
		options = append(options, otlpmetrichttp.WithHTTPClient(central.Transport()), otlpmetrichttp.WithCompression(otlpmetrichttp.NoCompression))
		if !configured {
			options = append(options, otlpmetrichttp.WithEndpointURL("http://boohtacord-local-export.invalid/v1/metrics"))
		}
	}
	if authorization := os.Getenv("OTEL_INGEST_AUTH"); authorization != "" {
		options = append(options, otlpmetrichttp.WithHeaders(map[string]string{"Authorization": authorization}))
	}
	exporter, err := otlpmetrichttp.New(ctx, options...)
	if err != nil {
		return nil, err
	}
	attrs := []attribute.KeyValue{
		attribute.String("service.name", "boohtacord-api"),
		attribute.String("service.version", os.Getenv("APP_VERSION")),
	}
	if central != nil {
		attrs = append(attrs, central.Attributes()...)
	}
	service, err := resource.New(ctx, resource.WithAttributes(attrs...))
	if err != nil {
		return nil, err
	}
	provider := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(service),
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(incident.MetricExporter{Exporter: exporter}, sdkmetric.WithInterval(15*time.Second))),
	)
	var stopHealth func() error
	if central != nil {
		stopHealth, err = central.RegisterMetrics(provider, os.Getenv("APP_VERSION"))
		if err != nil {
			_ = provider.Shutdown(ctx)
			return nil, err
		}
	}
	otel.SetMeterProvider(provider)
	return func(stop context.Context) error {
		var healthError error
		if stopHealth != nil {
			healthError = stopHealth()
		}
		return errors.Join(healthError, provider.Shutdown(stop))
	}, nil
}
