package acceptnotification_test

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"testing"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	accept "voice-platform/backend/internal/pushrelay/accept_notification"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
	fixture "voice-platform/backend/internal/pushrelay/test_scenario"
)

func TestRelayAcceptIsIdempotentScopedAndBounded(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t)
	now := time.Now().UTC()
	grant, key := fixture.Pair(t, pool, now)
	other, otherKey := fixture.Pair(t, pool, now)
	service := accept.Service{Database: pool, Box: fixture.Box(t), Namespace: "staging"}
	input := accept.Input{GrantID: grant.GrantID, Payload: delivery.Payload{Version: 1, Generation: 1, BindingRef: grant.BindingID, NotificationRef: uuid.NewString(), GroupRef: uuid.NewString(), Template: "direct_message", ExpiresAt: now.Add(time.Minute)}}
	request := fixture.Signed(t, key, "tenant", grant.TenantID, "POST", "/v1/notifications", input, now)
	result, err := service.Accept(ctx, request, input, now)
	if err != nil || result.State != "accepted_by_relay" {
		t.Fatal(result, err)
	}
	duplicate, err := service.Accept(ctx, fixture.Signed(t, key, "tenant", grant.TenantID, "POST", "/v1/notifications", input, now), input, now)
	if err != nil || duplicate.JobRef != result.JobRef {
		t.Fatal("retry duplicated logical job", duplicate, err)
	}
	if _, err = service.Accept(ctx, request, input, now); !errors.Is(err, auth.ErrDenied) {
		t.Fatal("signed replay", err)
	}
	if _, err = service.Accept(ctx, fixture.Signed(t, otherKey, "tenant", other.TenantID, "POST", "/v1/notifications", input, now), input, now); !errors.Is(err, accept.ErrRouteUnavailable) {
		t.Fatal("tenant isolation", err)
	}
	different := input
	different.Payload.Template = "activity"
	if _, err = service.Accept(ctx, fixture.Signed(t, key, "tenant", grant.TenantID, "POST", "/v1/notifications", different, now), different, now); !errors.Is(err, accept.ErrConflict) {
		t.Fatal("same reference changed payload", err)
	}
	forged := input
	forged.Payload.BindingRef = uuid.NewString()
	if _, err = service.Accept(ctx, fixture.Signed(t, key, "tenant", grant.TenantID, "POST", "/v1/notifications", forged, now), forged, now); !errors.Is(err, auth.ErrDenied) {
		t.Fatal("foreign binding accepted", err)
	}
	var pending, actual int
	if err = pool.QueryRow(ctx, `SELECT pending,(SELECT count(*) FROM relay_jobs WHERE state IN('pending','claimed','retry'))FROM relay_policy`).Scan(&pending, &actual); err != nil || pending != actual {
		t.Fatal("pending counter drift", pending, actual, err)
	}
	if _, err = pool.Exec(ctx, `UPDATE relay_policy SET max_pending=pending`); err != nil {
		t.Fatal(err)
	}
	next := input
	next.Payload.NotificationRef = uuid.NewString()
	if _, err = service.Accept(ctx, fixture.Signed(t, key, "tenant", grant.TenantID, "POST", "/v1/notifications", next, now), next, now); !errors.Is(err, auth.ErrLimit) {
		t.Fatal("unbounded queue", err)
	}
	if err = pool.QueryRow(ctx, `SELECT count(*)FROM relay_jobs WHERE kind='notification'`).Scan(&actual); err != nil || actual != 1 {
		t.Fatal(actual, err)
	}
}
