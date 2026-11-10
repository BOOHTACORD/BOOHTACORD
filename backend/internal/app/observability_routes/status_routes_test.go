package observabilityroutes

import (
	"context"
)

type statusMaintenanceStore struct {
	active bool
	cancel context.CancelFunc
}

func (store statusMaintenanceStore) Active(context.Context) (bool, error) {
	if store.cancel != nil {
		store.cancel()
	}
	return store.active, nil
}

func (statusMaintenanceStore) Set(context.Context, bool) error { return nil }
