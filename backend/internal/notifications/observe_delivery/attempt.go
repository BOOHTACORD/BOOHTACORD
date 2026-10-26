package observedelivery

import (
	"context"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

func Attempt(ctx context.Context, transport string) (context.Context, func(string, string)) {
	if transport != "web_push" && transport != "mobile_relay" {
		transport = "none"
	}
	ctx, span := otel.Tracer("boohtacord/notifications").Start(ctx, "notification.attempt")
	span.SetAttributes(attribute.String("notification.transport", transport))
	return ctx, func(outcome, reason string) {
		switch outcome {
		case "accepted_by_relay", "accepted_by_provider", "retry", "delivery_unknown", "permanent_failure", "invalid_binding":
		default:
			outcome = "other"
		}
		reason = Reason(reason)
		span.SetAttributes(attribute.String("notification.outcome", outcome), attribute.String("notification.reason", reason))
		if outcome != "accepted_by_relay" && outcome != "accepted_by_provider" {
			span.SetStatus(codes.Error, reason)
		}
		span.End()
	}
}
