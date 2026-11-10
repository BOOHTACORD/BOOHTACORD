package rostermatrix

import (
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
)

// CandidateEvent classifies initial application events without retaining payloads.
func CandidateEvent(data []byte, rooms []string) (string, error) {
	if len(data) > 512<<10 {
		return "", errors.New("event exceeds fixture limit")
	}
	var event struct {
		Kind    string          `json:"kind"`
		Payload json.RawMessage `json:"payload"`
	}
	if json.Unmarshal(data, &event) != nil || event.Kind == "" {
		return "", errors.New("malformed application event")
	}
	switch event.Kind {
	case "connection.ready":
		return "ready", nil
	case "presence.changed":
		return "presence", nil
	case "voice.roster.unavailable":
		return "", errors.New("roster unavailable")
	case "voice.roster.snapshot":
		var header struct {
			Version    int       `json:"version"`
			Generation string    `json:"generation"`
			Revision   uint64    `json:"revision"`
			ObservedAt time.Time `json:"observed_at"`
		}
		if json.Unmarshal(event.Payload, &header) != nil || header.Version != 1 || uuid.Validate(header.Generation) != nil || header.Revision == 0 || header.ObservedAt.IsZero() {
			return "", errors.New("invalid roster version or generation")
		}
		if err := ValidateEmptySnapshot(event.Payload, rooms); err != nil {
			return "", err
		}
		return "roster", nil
	case "maintenance.snapshot", "maintenance.changed":
		var state struct {
			Version    int    `json:"version"`
			Generation string `json:"generation"`
			Revision   uint64 `json:"revision"`
			Active     *bool  `json:"active"`
		}
		if json.Unmarshal(event.Payload, &state) != nil || state.Version != 1 || uuid.Validate(state.Generation) != nil || state.Revision == 0 || state.Active == nil {
			return "", errors.New("unknown maintenance state")
		}
		if event.Kind == "maintenance.snapshot" {
			return "maintenance", nil
		}
		if *state.Active {
			return "maintenance_change", nil
		}
		return "", nil
	default:
		return "", nil
	}
}
