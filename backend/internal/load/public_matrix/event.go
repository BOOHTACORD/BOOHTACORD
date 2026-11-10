package publicmatrix

import (
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
)

func Classify(raw []byte) (string, error) {
	if len(raw) > 4096 {
		return "", errors.New("public frame exceeds fixture limit")
	}
	var envelope struct {
		ID         string          `json:"event_id"`
		OccurredAt time.Time       `json:"occurred_at"`
		Kind       string          `json:"kind"`
		Payload    json.RawMessage `json:"payload"`
	}
	var fields map[string]json.RawMessage
	var keys map[string]json.RawMessage
	if json.Unmarshal(raw, &keys) != nil || len(keys) != 4 || json.Unmarshal(raw, &envelope) != nil || uuid.Validate(envelope.ID) != nil || envelope.OccurredAt.IsZero() || json.Unmarshal(envelope.Payload, &fields) != nil || fields == nil {
		return "", errors.New("invalid public event")
	}
	if envelope.Kind == "connection.ready" && len(fields) == 0 {
		return "ready", nil
	}
	if (envelope.Kind != "maintenance.snapshot" && envelope.Kind != "maintenance.changed") || len(fields) != 4 {
		return "", errors.New("unexpected public event")
	}
	var state struct {
		Version    int    `json:"version"`
		Generation string `json:"generation"`
		Revision   uint64 `json:"revision"`
		Active     *bool  `json:"active"`
	}
	if json.Unmarshal(envelope.Payload, &state) != nil || state.Version != 1 || uuid.Validate(state.Generation) != nil || state.Revision == 0 || state.Revision > 9007199254740991 || state.Active == nil {
		return "", errors.New("invalid public maintenance state")
	}
	if envelope.Kind == "maintenance.snapshot" {
		return "maintenance", nil
	}
	return "changed", nil
}
