package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"testing"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestAgentKeepsReviewedHistogramSamplesAsWellAsCounters(t *testing.T) {
	t.Setenv("PUBLIC_ORIGIN", "https://qa.example.test")
	i, _ := identity.New()
	path := filepath.Join(t.TempDir(), "agent.json")
	if err := agentConfig(path, i); err != nil {
		t.Fatal(err)
	}
	body, _ := os.ReadFile(path)
	var config map[string]any
	if err := json.Unmarshal(body, &config); err != nil {
		t.Fatal(err)
	}
	receiver := config["receivers"].(map[string]any)["prometheus"].(map[string]any)
	scrape := receiver["config"].(map[string]any)["scrape_configs"].([]any)[0].(map[string]any)
	filter := scrape["metric_relabel_configs"].([]any)[0].(map[string]any)["regex"].(string)
	allow := regexp.MustCompile("^(?:" + filter + ")$")
	for _, name := range []string{"livekit_room_total", "livekit_packet_total", "livekit_jitter_us_bucket", "livekit_jitter_us_count", "livekit_rtt_ms_sum", "livekit_packet_loss_percent_bucket", "livekit_packet_out_of_order_total"} {
		if !allow.MatchString(name) {
			t.Fatalf("reviewed sample dropped: %s", name)
		}
	}
	if allow.MatchString("livekit_private_metric") {
		t.Fatal("unknown metric allowed")
	}
}
