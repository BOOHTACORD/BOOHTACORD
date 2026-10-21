// Package centralprojection is the deny-by-default boundary for external OTLP.
package centralprojection

import (
	"encoding/base64"
	"errors"
	"github.com/google/uuid"
	collector "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	common "go.opentelemetry.io/proto/otlp/common/v1"
	resource "go.opentelemetry.io/proto/otlp/resource/v1"
	"google.golang.org/protobuf/proto"
	"strings"
	"time"
	flow "voice-platform/backend/internal/observability/flow_contract"
	identity "voice-platform/backend/internal/observability/installation"
)

const MaxBytes = 2 * 1024 * 1024

var ErrPolicy = errors.New("external telemetry policy rejected")

func String(k, v string) *common.KeyValue {
	return &common.KeyValue{Key: k, Value: &common.AnyValue{Value: &common.AnyValue_StringValue{StringValue: v}}}
}
func value(a *common.AnyValue) any {
	if a == nil {
		return nil
	}
	switch v := a.Value.(type) {
	case *common.AnyValue_StringValue:
		return v.StringValue
	case *common.AnyValue_IntValue:
		return v.IntValue
	case *common.AnyValue_DoubleValue:
		return v.DoubleValue
	}
	return nil
}
func Correlation(i identity.Identity, key, raw string) string {
	if raw == "" || len(raw) > 128 {
		return ""
	}
	if len(i.Key) == 32 {
		return i.Pseudonym(strings.TrimSuffix(key, ".id"), raw)
	}
	decoded, err := base64.RawURLEncoding.DecodeString(raw)
	if err != nil || len(decoded) != 32 {
		return ""
	}
	return raw
}
func Resource(in *resource.Resource, i identity.Identity) (*resource.Resource, error) {
	name, version, instance := "boohtacord-api", "", ""
	if in != nil {
		for _, a := range in.Attributes {
			if a == nil || a.Value == nil {
				continue
			}
			s := a.Value.GetStringValue()
			switch a.Key {
			case "boohtacord.installation.id":
				if s != i.ID {
					return nil, ErrPolicy
				}
			case "service.name":
				switch s {
				case "boohtacord-api", "boohtacord-worker", "boohtacord-web", "boohtacord-android", "boohtacord-ios", "boohtacord-macos", "boohtacord-windows", "boohtacord-livekit":
					name = s
				default:
					return nil, ErrPolicy
				}
			case "service.version":
				if flow.Valid("app.client.version", s) {
					version = s
				}
			case "service.instance.id":
				if id, err := uuid.Parse(s); err == nil && id.Version() == 4 && id.String() == s {
					instance = s
				}
			}
		}
	}
	attrs := []*common.KeyValue{String("service.namespace", "boohtacord"), String("service.name", name), String("boohtacord.installation.id", i.ID)}
	if version != "" {
		attrs = append(attrs, String("service.version", version))
	}
	if instance != "" && (name == "boohtacord-api" || name == "boohtacord-worker" || name == "boohtacord-livekit") {
		attrs = append(attrs, String("service.instance.id", instance))
	}
	return &resource.Resource{Attributes: attrs}, nil
}
func attributes(in []*common.KeyValue, i identity.Identity) []*common.KeyValue {
	out := []*common.KeyValue{}
	seen := map[string]bool{}
	for _, a := range in {
		if a == nil || a.Value == nil || seen[a.Key] {
			continue
		}
		seen[a.Key] = true
		if a.Key == "user.id" || a.Key == "session.id" || a.Key == "app.flow.id" || a.Key == "app.visit.id" || a.Key == "app.media.session.id" {
			if s := Correlation(i, a.Key, a.Value.GetStringValue()); s != "" {
				out = append(out, String(a.Key, s))
			}
			continue
		}
		if f, ok := flow.Fields[a.Key]; ok && f.Kind != "version" && f.Kind != "id" && flow.Valid(a.Key, value(a.Value)) {
			out = append(out, a)
		}
		if a.Key == "http.route" && OperationNames[a.Value.GetStringValue()] {
			out = append(out, a)
		}
		if a.Key == "http.request.method" && labelValues["method"][a.Value.GetStringValue()] {
			out = append(out, a)
		}
		if a.Key == "http.response.status_code" {
			if n, ok := value(a.Value).(int64); ok && n >= 100 && n <= 599 {
				out = append(out, a)
			}
		}
		if len(out) >= 32 {
			break
		}
	}
	return out
}
func Traces(raw []byte, i identity.Identity) ([]byte, error) {
	if len(raw) > MaxBytes {
		return nil, ErrPolicy
	}
	var batch collector.ExportTraceServiceRequest
	if (proto.UnmarshalOptions{DiscardUnknown: true}).Unmarshal(raw, &batch) != nil {
		return nil, ErrPolicy
	}
	now := uint64(time.Now().UnixNano())
	count := 0
	for _, r := range batch.ResourceSpans {
		if r == nil {
			return nil, ErrPolicy
		}
		clean, err := Resource(r.Resource, i)
		if err != nil {
			return nil, err
		}
		r.Resource = clean
		r.SchemaUrl = ""
		for _, scope := range r.ScopeSpans {
			if scope == nil {
				return nil, ErrPolicy
			}
			scope.Scope = &common.InstrumentationScope{Name: "boohtacord-central-v1"}
			scope.SchemaUrl = ""
			for _, s := range scope.Spans {
				count++
				if s == nil || count > 256 || len(s.TraceId) != 16 || len(s.SpanId) != 8 || s.EndTimeUnixNano < s.StartTimeUnixNano || s.EndTimeUnixNano > now+uint64(time.Minute) || s.StartTimeUnixNano+uint64(15*time.Minute) < now {
					return nil, ErrPolicy
				}
				name := s.Name
				if !flow.Operations[name] && !OperationNames[name] {
					name = "server.operation"
				}
				if identityConflict(s.Attributes, i.ID) {
					return nil, ErrPolicy
				}
				s.Name = name
				s.TraceState = ""
				s.Attributes = attributes(s.Attributes, i)
				s.Events = nil
				s.DroppedEventsCount = 0
				s.DroppedAttributesCount = 0
				if s.Status != nil {
					if s.Status.Code < 0 || s.Status.Code > 2 {
						return nil, ErrPolicy
					}
					s.Status.Message = ""
				}
				if len(s.Links) > 8 {
					s.Links = s.Links[:8]
				}
				for _, link := range s.Links {
					if link == nil || len(link.TraceId) != 16 || len(link.SpanId) != 8 {
						return nil, ErrPolicy
					}
					link.TraceState = ""
					link.Attributes = attributes(link.Attributes, i)
					link.DroppedAttributesCount = 0
				}
				if s.Kind < 0 || s.Kind > 5 {
					return nil, ErrPolicy
				}
			}
		}
	}
	if count == 0 {
		return nil, ErrPolicy
	}
	return proto.Marshal(&batch)
}

func identityConflict(attrs []*common.KeyValue, id string) bool {
	for _, a := range attrs {
		if a != nil && (a.Key == "installation_id" || a.Key == "boohtacord.installation.id") && (a.Value == nil || a.Value.GetStringValue() != id) {
			return true
		}
	}
	return false
}
