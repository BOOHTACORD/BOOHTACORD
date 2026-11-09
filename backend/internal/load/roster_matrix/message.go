package rostermatrix

import (
	"encoding/json"
	"errors"
	"github.com/google/uuid"
	"time"
)

// MessageID extracts only the metadata needed to correlate a synthetic message.
func MessageID(data []byte) (string, error) {
	var event struct {
		Kind    string          `json:"kind"`
		Payload json.RawMessage `json:"payload"`
	}
	if len(data) > 512<<10 || json.Unmarshal(data, &event) != nil || event.Kind == "" {
		return "", errors.New("invalid message event")
	}
	if event.Kind != "message.created" {
		return "", nil
	}
	var payload struct {
		MessageID string `json:"message_id"`
	}
	if json.Unmarshal(event.Payload, &payload) != nil || uuid.Validate(payload.MessageID) != nil {
		return "", errors.New("invalid message id")
	}
	return payload.MessageID, nil
}

// MessageOccurredAt reads the server event timestamp without retaining payload data.
func MessageOccurredAt(data []byte) (time.Time, error) {
	var event struct {
		OccurredAt time.Time `json:"occurred_at"`
	}
	if len(data) > 512<<10 || json.Unmarshal(data, &event) != nil || event.OccurredAt.IsZero() {
		return time.Time{}, errors.New("invalid message timestamp")
	}
	return event.OccurredAt, nil
}
