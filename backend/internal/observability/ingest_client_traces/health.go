package ingestclienttraces

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"net/http"
	"time"
)

var relayRequests, _ = otel.Meter("boohtacord/relay").Int64Counter("boohtacord.telemetry.relay.requests")
var relayLatency, _ = otel.Meter("boohtacord/relay").Float64Histogram("boohtacord.telemetry.relay.duration", metric.WithUnit("s"))
var relayFreshness, _ = otel.Meter("boohtacord/relay").Int64Gauge("boohtacord.telemetry.relay.last_accept", metric.WithUnit("s"))

type healthWriter struct {
	http.ResponseWriter
	status int
}

func (w *healthWriter) WriteHeader(status int) {
	if w.status == 0 {
		w.status = status
	}
	w.ResponseWriter.WriteHeader(status)
}
func (w *healthWriter) Write(body []byte) (int, error) {
	if w.status == 0 {
		w.status = 200
	}
	return w.ResponseWriter.Write(body)
}
func withRelayHealth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		source := requestPlatform(r)
		r = r.WithContext(context.WithValue(r.Context(), relaySourceKey{}, source))
		captured := &healthWriter{ResponseWriter: w}
		defer func() {
			panicValue := recover()
			code := captured.status
			if panicValue != nil {
				code = 500
			} else if code == 0 {
				code = 200
			}
			labels := metric.WithAttributes(attribute.Int("http.response.status_code", code), attribute.String("platform", source))
			relayRequests.Add(r.Context(), 1, labels)
			relayLatency.Record(r.Context(), time.Since(started).Seconds(), labels)
			if code == 202 && captured.Header().Get("X-Telemetry-Accepted") != "0" {
				relayFreshness.Record(r.Context(), time.Now().Unix(), metric.WithAttributes(attribute.String("platform", source)))
			}
			if panicValue != nil {
				panic(panicValue)
			}
		}()
		next.ServeHTTP(captured, r)
	})
}

// The source label is an enum from the existing relay protocol, never an identity.
type relaySourceKey struct{}

func requestPlatform(request *http.Request) string {
	platform := request.Header.Get("X-Client-Platform")
	if platforms[platform] {
		return platform
	}
	return "unknown"
}
func sourcePlatform(ctx context.Context) attribute.KeyValue {
	source, _ := ctx.Value(relaySourceKey{}).(string)
	if !platforms[source] {
		source = "unknown"
	}
	return attribute.String("platform", source)
}
