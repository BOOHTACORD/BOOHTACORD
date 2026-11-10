package runrostermatrix

import (
	"context"
	"errors"
	"voice-platform/backend/internal/load/observe_resources"
)

// serverDeliveryProbe copies only a fixed, identity-free histogram projection.
func serverDeliveryProbe(guard observe_resources.Guard) func(context.Context) (map[string]float64, error) {
	return func(ctx context.Context) (map[string]float64, error) {
		snapshot, err := guard.Check(ctx)
		if err != nil || snapshot.MetricsStatus != "AVAILABLE" {
			return nil, errors.New("metrics unavailable")
		}
		const prefix = "voice_platform_realtime_event_delivery_seconds"
		keys := []string{"_count", "_sum", "_bucket.le.0.005", "_bucket.le.0.01", "_bucket.le.0.025", "_bucket.le.0.05", "_bucket.le.0.1", "_bucket.le.0.25", "_bucket.le.0.5", "_bucket.le.1", "_bucket.le.2.5", "_bucket.le.5", "_bucket.le.10", "_bucket.le.+Inf"}
		values := make(map[string]float64, len(keys))
		for _, suffix := range keys {
			value, ok := snapshot.Metrics[prefix+suffix]
			if !ok {
				return nil, errors.New("incomplete latency histogram")
			}
			values[suffix] = value
		}
		for _, key := range []string{
			"voice_platform_realtime_session_revalidation_seconds_count",
			"voice_platform_realtime_session_revalidation_seconds_sum",
			"voice_platform_database_acquire_duration_seconds_count",
			"voice_platform_database_acquire_duration_seconds_sum",
			"voice_platform_database_pool_empty_acquire_wait_seconds_total",
			"voice_platform_database_acquires_pending",
			"voice_platform_database_pool_acquired",
			"voice_platform_database_pool_max",
		} {
			value, ok := snapshot.Metrics[key]
			if !ok {
				return nil, errors.New("incomplete database or revalidation metrics")
			}
			values[key] = value
		}
		const stageName = "voice_platform_realtime_event_stage_seconds."
		for _, stage := range []string{"before_handler", "handler"} {
			for _, suffix := range []string{"count", "sum", "bucket.0.001", "bucket.0.0025", "bucket.0.005", "bucket.0.01", "bucket.0.025", "bucket.0.05", "bucket.0.1", "bucket.0.25", "bucket.0.5", "bucket.1", "bucket.2.5", "bucket.5", "bucket.10", "bucket.+Inf"} {
				key := stageName + stage + "." + suffix
				if value, ok := snapshot.Metrics[key]; ok {
					values[key] = value
				}
			}
		}
		return values, nil
	}
}
