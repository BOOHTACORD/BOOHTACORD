package main

import (
	"encoding/json"
	"errors"
	"os"
	identity "voice-platform/backend/internal/observability/installation"
)

// JSON is valid Collector YAML. This private file contains only a local agent
// credential, never the installation pseudonymization key or central credential.
func agentConfig(path string, i identity.Identity) error {
	origin := os.Getenv("PUBLIC_ORIGIN")
	if origin == "" {
		return errors.New("PUBLIC_ORIGIN required for local agent")
	}
	config := map[string]any{
		"receivers":  map[string]any{"prometheus": map[string]any{"config": map[string]any{"scrape_configs": []any{map[string]any{"job_name": "boohtacord-livekit", "scrape_interval": "15s", "static_configs": []any{map[string]any{"targets": []string{"livekit:6789"}}}, "metric_relabel_configs": []any{map[string]any{"source_labels": []string{"__name__"}, "regex": "livekit_(room_total|participant_total|connection_total|packet_total|packet_bytes|packet_loss_total|jitter_us|rtt_ms)", "action": "keep"}, map[string]any{"regex": "node_id|country|room|room_id|participant_id|identity|user_id", "action": "labeldrop"}}}}}}},
		"processors": map[string]any{"memory_limiter": map[string]any{"check_interval": "1s", "limit_mib": 64, "spike_limit_mib": 16}, "resource": map[string]any{"attributes": []any{map[string]any{"key": "service.name", "value": "boohtacord-livekit", "action": "upsert"}, map[string]any{"key": "boohtacord.installation.id", "value": i.ID, "action": "upsert"}}}},
		"exporters":  map[string]any{"otlphttp": map[string]any{"metrics_endpoint": "http://api:8080/internal/telemetry/metrics", "headers": map[string]string{"Authorization": "Bearer " + i.Pseudonym("local-agent", i.ID), "Origin": origin}, "timeout": "3s", "compression": "none", "sending_queue": map[string]any{"enabled": false}, "retry_on_failure": map[string]any{"enabled": false}}},
		"service":    map[string]any{"pipelines": map[string]any{"metrics": map[string]any{"receivers": []string{"prometheus"}, "processors": []string{"memory_limiter", "resource"}, "exporters": []string{"otlphttp"}}}},
	}
	body, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	defer file.Close()
	_, err = file.Write(body)
	return err
}
