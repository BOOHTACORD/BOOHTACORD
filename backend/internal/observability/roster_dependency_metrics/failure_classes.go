package rosterdependencymetrics

import (
	"context"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
)

type failureClasses struct {
	transport, http             *prometheus.CounterVec
	transportExport, httpExport metric.Int64Counter
}

func newFailureClasses(registry *prometheus.Registry) *failureClasses {
	f := &failureClasses{
		transport: prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_sfu_room_service_transport_failures_total", Help: "RoomService transport failures by bounded class."}, []string{"method", "class"}),
		http:      prometheus.NewCounterVec(prometheus.CounterOpts{Name: "voice_platform_sfu_room_service_http_failures_total", Help: "RoomService failed HTTP responses by bounded status family."}, []string{"method", "status_class"}),
	}
	registry.MustRegister(f.transport, f.http)
	meter := otel.Meter("voice-platform/roster")
	f.transportExport, _ = meter.Int64Counter("voice_platform_sfu_room_service_transport_failures_total")
	f.httpExport, _ = meter.Int64Counter("voice_platform_sfu_room_service_http_failures_total")
	return f
}

func (m *Metrics) FailureClass(method, class, status string) {
	if method != "ListRooms" && method != "ListParticipants" {
		method = "other"
	}
	if class != "" {
		switch class {
		case "dns", "connect", "reset", "timeout", "canceled":
		default:
			class = "other"
		}
		m.classes.transport.WithLabelValues(method, class).Inc()
		m.classes.transportExport.Add(context.Background(), 1, metric.WithAttributes(attribute.String("method", method), attribute.String("class", class)))
	}
	if status != "" {
		switch status {
		case "401", "403", "404", "5xx":
		default:
			status = "other"
		}
		m.classes.http.WithLabelValues(method, status).Inc()
		m.classes.httpExport.Add(context.Background(), 1, metric.WithAttributes(attribute.String("method", method), attribute.String("status_class", status)))
	}
}
