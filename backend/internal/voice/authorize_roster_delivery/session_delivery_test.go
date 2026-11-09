package authorizerosterdelivery

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessiondelivery "voice-platform/backend/internal/identity/serialize_session_delivery"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type deliveryFunc func(context.Context, auth.Principal, func(context.Context, pgx.Tx) error) error

func (f deliveryFunc) WithSessionTx(ctx context.Context, who auth.Principal, write func(context.Context, pgx.Tx) error) error {
	return f(ctx, who, write)
}

func TestDeliverySessionGuardFailsClosed(t *testing.T) {
	ctx := context.Background()
	write := func(context.Context) error { t.Fatal("write must not be called"); return nil }
	if err := New(nil, nil).WithRoster(ctx, auth.Principal{}, roster.Result{}, write); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("missing guard: %v", err)
	}
	for _, pair := range []struct{ source, want error }{
		{sessiondelivery.ErrSession, ErrSession},
		{sessiondelivery.ErrUnavailable, ErrUnavailable},
	} {
		fake := deliveryFunc(func(context.Context, auth.Principal, func(context.Context, pgx.Tx) error) error { return pair.source })
		if err := New(nil, nil, fake).WithRoster(ctx, auth.Principal{}, roster.Result{}, write); !errors.Is(err, pair.want) {
			t.Fatalf("mapped error %v, want %v", err, pair.want)
		}
	}
}
