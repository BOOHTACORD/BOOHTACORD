package observe_resources

import (
	"context"
	"errors"
	"net/http"
)

// ChangeMaintenance only operates through the validated local fixture guard.
func (g Guard) ChangeMaintenance(ctx context.Context) error {
	snapshot, err := g.Check(ctx)
	if err != nil {
		return err
	}
	if snapshot.MetricsStatus != "AVAILABLE" {
		return errors.New("fixture metrics unavailable")
	}
	response, err := g.Request(ctx, http.MethodPost, "/maintenance/on")
	if err != nil {
		return errors.New("maintenance fixture controller unavailable")
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusNoContent {
		return errors.New("maintenance fixture controller refused")
	}
	return nil
}
