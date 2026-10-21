package centralgateway

import (
	"crypto/sha256"
	"encoding/hex"
	collector "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	common "go.opentelemetry.io/proto/otlp/common/v1"
	metric "go.opentelemetry.io/proto/otlp/metrics/v1"
	"google.golang.org/protobuf/proto"
	"sort"
	"time"
)

func (g *Gateway) cardinality(id string, body []byte) bool {
	var batch collector.ExportMetricsServiceRequest
	if proto.Unmarshal(body, &batch) != nil {
		return false
	}
	keys := map[string]bool{}
	add := func(name string, attrs []*common.KeyValue) {
		parts := []string{name}
		for _, a := range attrs {
			parts = append(parts, a.Key+"="+a.Value.GetStringValue())
		}
		sort.Strings(parts)
		hash := sha256.New()
		for _, s := range parts {
			hash.Write([]byte(s + "\x00"))
		}
		keys[id+":"+hex.EncodeToString(hash.Sum(nil))] = true
	}
	for _, r := range batch.ResourceMetrics {
		for _, s := range r.ScopeMetrics {
			for _, m := range s.Metrics {
				switch d := m.Data.(type) {
				case *metric.Metric_Gauge:
					for _, p := range d.Gauge.DataPoints {
						add(m.Name, p.Attributes)
					}
				case *metric.Metric_Sum:
					for _, p := range d.Sum.DataPoints {
						add(m.Name, p.Attributes)
					}
				case *metric.Metric_Histogram:
					for _, p := range d.Histogram.DataPoints {
						add(m.Name, p.Attributes)
					}
				}
			}
		}
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.series == nil {
		g.series = map[string]time.Time{}
	}
	now := time.Now()
	counts := map[string]int{}
	for key, at := range g.series {
		if now.Sub(at) > time.Hour {
			delete(g.series, key)
		} else {
			counts[key[:36]]++
		}
	}
	novel := 0
	for key := range keys {
		if _, ok := g.series[key]; !ok {
			novel++
		}
	}
	if counts[id]+novel > 4096 || len(g.series)+novel > 65536 {
		return false
	}
	for key := range keys {
		g.series[key] = now
	}
	return true
}
