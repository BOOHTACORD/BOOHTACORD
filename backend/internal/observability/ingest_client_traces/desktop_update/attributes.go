package desktopupdate

import (
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	"regexp"
)

var phases = map[string]bool{"check": true, "download": true, "verify": true, "stage": true, "ready": true, "apply": true, "restart": true, "restore": true, "completed": true, "rollback": true, "failed": true, "cancelled": true}
var reasons = map[string]bool{"signature": true, "publisher": true, "identity": true, "source": true, "digest": true, "size": true, "network": true, "http": true, "disk_space": true, "installation_location": true, "scope_changed": true, "cancelled": true, "native_apply": true, "bootstrap_identity": true, "other": true}

func Clean(input []*commonpb.KeyValue, platform string) []*commonpb.KeyValue {
	out := []*commonpb.KeyValue{{Key: "platform", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: platform}}}}
	seen := map[string]bool{"platform": true}
	for _, a := range input {
		if a == nil || a.Value == nil || seen[a.Key] {
			continue
		}
		value := a.Value.GetStringValue()
		valid := false
		switch a.Key {
		case "phase":
			valid = phases[value]
		case "reason":
			valid = reasons[value]
		case "version":
			valid = regexp.MustCompile(`^[0-9]{1,6}\.[0-9]{1,6}\.[0-9]{1,6}$`).MatchString(value)
		case "duration_ms":
			v, ok := a.Value.Value.(*commonpb.AnyValue_IntValue)
			valid = ok && v.IntValue >= 0 && v.IntValue <= 1800000
		}
		if valid {
			out = append(out, a)
			seen[a.Key] = true
		}
	}
	return out
}
