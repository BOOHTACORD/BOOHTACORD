package centralprojection

import (
	collector "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	common "go.opentelemetry.io/proto/otlp/common/v1"
	metric "go.opentelemetry.io/proto/otlp/metrics/v1"
	"google.golang.org/protobuf/proto"
	"math"
	"strconv"
	"time"
	flow "voice-platform/backend/internal/observability/flow_contract"
	identity "voice-platform/backend/internal/observability/installation"
)

var labelValues = map[string]map[string]bool{
	"period":    {"today": true, "yesterday": true},
	"platform":  {"web": true, "ios_web": true, "android_web": true, "desktop_web": true, "android_native": true, "ios_native": true, "windows_native": true, "macos_native": true, "desktop_native": true, "macos": true, "windows": true, "android": true, "ios": true},
	"method":    {"GET": true, "POST": true, "PATCH": true, "PUT": true, "DELETE": true, "OPTIONS": true, "HEAD": true},
	"codec":     {"vp8": true, "h264": true, "vp9": true, "av1": true, "unknown": true},
	"direction": {"sender": true, "receiver": true, "send": true, "receive": true},
	"state":     {"active": true, "inactive": true, "unavailable": true, "stale": true, "unknown": true, "waiting_first_frame": true, "playing": true, "stalled": true},
	"result":    {"success": true, "failed": true, "timeout": true, "unavailable": true, "denied": true, "unknown": true},
	"profile":   {"720p30": true, "720p60": true, "1080p30": true, "1080p60": true, "1440p30": true, "1440p60": true},
}

func MetricLabels(in []*common.KeyValue, i identity.Identity, service, instance string) []*common.KeyValue {
	out := []*common.KeyValue{String("installation_id", i.ID), String("service_name", service)}
	if instance != "" {
		out = append(out, String("service_instance_id", instance))
	}
	seen := map[string]bool{}
	for _, a := range in {
		if a == nil || a.Value == nil || seen[a.Key] {
			continue
		}
		seen[a.Key] = true
		key := a.Key
		if key == "http.request.method" {
			key = "method"
		}
		if key == "http.response.status_code" {
			key = "status"
		}
		s := a.Value.GetStringValue()
		if key == "status" && s == "" {
			if number, ok := value(a.Value).(int64); ok {
				s = strconv.FormatInt(number, 10)
			}
		}
		if labelValues[key][s] || (key == "operation" && flow.Operations[s]) {
			out = append(out, String(key, s))
			continue
		}
		if key == "status" {
			n, err := strconv.Atoi(s)
			if err == nil && n >= 100 && n <= 599 {
				out = append(out, String("status", strconv.Itoa(n)))
			}
		}
	}
	return out
}
func finite(n float64) bool { return !math.IsNaN(n) && !math.IsInf(n, 0) }
func Metrics(raw []byte, i identity.Identity) ([]byte, error) {
	if len(raw) > MaxBytes {
		return nil, ErrPolicy
	}
	var batch collector.ExportMetricsServiceRequest
	if (proto.UnmarshalOptions{DiscardUnknown: true}).Unmarshal(raw, &batch) != nil {
		return nil, ErrPolicy
	}
	points := 0
	instruments := 0
	for _, r := range batch.ResourceMetrics {
		if r == nil {
			return nil, ErrPolicy
		}
		clean, err := Resource(r.Resource, i)
		if err != nil {
			return nil, err
		}
		r.Resource = clean
		r.SchemaUrl = ""
		name, instance := "", ""
		for _, a := range clean.Attributes {
			if a.Key == "service.name" {
				name = a.Value.GetStringValue()
			}
			if a.Key == "service.instance.id" {
				instance = a.Value.GetStringValue()
			}
		}
		for _, s := range r.ScopeMetrics {
			if s == nil {
				return nil, ErrPolicy
			}
			s.Scope = &common.InstrumentationScope{Name: "boohtacord-central-v1"}
			s.SchemaUrl = ""
			kept := []*metric.Metric{}
			for _, m := range s.Metrics {
				if m == nil || !MetricNames[m.Name] {
					continue
				}
				instruments++
				if instruments > 128 {
					return nil, ErrPolicy
				}
				m.Description = ""
				if m.Unit != "s" && m.Unit != "By" && m.Unit != "ms" && m.Unit != "1" {
					m.Unit = ""
				}
				m.Metadata = nil
				valid := true
				var numbers []*metric.NumberDataPoint
				switch d := m.Data.(type) {
				case *metric.Metric_Gauge:
					numbers = d.Gauge.DataPoints
				case *metric.Metric_Sum:
					numbers = d.Sum.DataPoints
				case *metric.Metric_Histogram:
					for _, p := range d.Histogram.DataPoints {
						if p == nil || len(p.ExplicitBounds) > 64 || len(p.BucketCounts) > 65 || len(p.BucketCounts) != len(p.ExplicitBounds)+1 || !finite(p.GetSum()) {
							return nil, ErrPolicy
						}
						if identityConflict(p.Attributes, i.ID) {
							return nil, ErrPolicy
						}
						p.Attributes = MetricLabels(p.Attributes, i, name, instance)
						p.Exemplars = nil
						previous := math.Inf(-1)
						for _, bound := range p.ExplicitBounds {
							if !finite(bound) || bound <= previous {
								return nil, ErrPolicy
							}
							previous = bound
						}
						points++
						if !metricTime(p.TimeUnixNano, p.StartTimeUnixNano) {
							return nil, ErrPolicy
						}
					}
				default:
					valid = false
				}
				if !valid {
					continue
				}
				for _, p := range numbers {
					if p == nil || !finite(p.GetAsDouble()) || !metricTime(p.TimeUnixNano, p.StartTimeUnixNano) {
						return nil, ErrPolicy
					}
					if identityConflict(p.Attributes, i.ID) {
						return nil, ErrPolicy
					}
					p.Attributes = MetricLabels(p.Attributes, i, name, instance)
					p.Exemplars = nil
					points++
				}
				if points > 2048 {
					return nil, ErrPolicy
				}
				kept = append(kept, m)
			}
			s.Metrics = kept
		}
	}
	return proto.Marshal(&batch)
}
func metricTime(at, start uint64) bool {
	now := uint64(time.Now().UnixNano())
	return (at == 0 || at <= now+uint64(time.Minute) && at+uint64(15*time.Minute) >= now) && (start == 0 || at == 0 || start <= at)
}
