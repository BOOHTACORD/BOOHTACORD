package observe_resources

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"
	"voice-platform/backend/internal/load/validate_target"
)

type Snapshot struct {
	MetricsStatus                          string
	Owner, Dataset, Origin, Commit, DBName string
	At                                     time.Time
	Accounts                               int
	CPUPercent                             float64
	RSSBytes, FreeBytes                    int64
	Metrics                                map[string]float64
}
type Guard struct {
	Manifest validate_target.Manifest
	Client   *http.Client
}

func (g Guard) Request(ctx context.Context, method, path string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, method, g.Manifest.Guard+path, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("X-Load-Nonce", g.Manifest.Nonce)
	return g.Client.Do(req)
}
func (g Guard) Check(ctx context.Context) (Snapshot, error) {
	var s Snapshot
	response, err := g.Request(ctx, "GET", "/snapshot")
	if err != nil {
		return s, ErrUnavailable
	}
	defer response.Body.Close()
	if response.StatusCode == http.StatusServiceUnavailable {
		switch response.Header.Get("X-QA-Guard-Stage") {
		case "fixture_verification":
			return s, ErrFixtureVerification
		case "resource_snapshot":
			return s, ErrResourceSnapshot
		case "resource_metrics":
			return s, ErrResourceMetrics
		case "resource_metrics_timeout":
			return s, ErrMetricsTimeout
		case "resource_metrics_http":
			return s, ErrMetricsHTTP
		case "resource_metrics_unavailable":
			return s, ErrMetricsUnavailable
		case "resource_metrics_invalid":
			return s, ErrMetricsInvalid
		}
	}
	if response.StatusCode != 200 {
		return s, ErrDenied
	}
	if json.NewDecoder(io.LimitReader(response.Body, 65536)).Decode(&s) != nil {
		return s, ErrInvalid
	}
	m := g.Manifest
	if s.Owner != m.Owner || s.Dataset != m.Dataset || s.Origin != m.Origin || s.Commit != m.Commit || s.DBName != "qa" || s.Accounts != len(m.Accounts)+1 {
		return s, ErrForeign
	}
	age := time.Since(s.At)
	if age < 0 || age > 5*time.Second {
		return s, ErrStale
	}
	if s.CPUPercent < 0 || s.CPUPercent > 90 || s.RSSBytes < 1 || s.RSSBytes > 1<<30 || s.FreeBytes < 512<<20 {
		return s, ErrThreshold
	}
	return s, nil
}
func (g Guard) Fault(ctx context.Context, name string) error {
	allowed := map[string]bool{"db_pressure": true, "sfu_outage": true, "slow_telemetry": true, "disk_pressure": true, "restore": true}
	if !allowed[name] {
		return errors.New("unknown isolated fault")
	}
	if name != "restore" {
		if _, err := g.Check(ctx); err != nil {
			return err
		}
	}
	r, err := g.Request(ctx, "POST", "/fault/"+name)
	if err != nil {
		return errors.New("fault controller unavailable")
	}
	defer r.Body.Close()
	if r.StatusCode != 204 {
		return errors.New("fault controller refused")
	}
	return nil
}
