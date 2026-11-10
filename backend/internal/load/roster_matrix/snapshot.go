package rostermatrix

import (
	"encoding/json"
	"errors"
)

// ValidateEmptySnapshot only checks a fixture with no connected media clients.
// It cannot establish correctness for populated rooms or media capacity.
func ValidateEmptySnapshot(data []byte, rooms []string) error {
	if len(data) > 512<<10 {
		return errors.New("snapshot exceeds fixture limit")
	}
	var snapshot struct {
		Channels []struct {
			ID           string            `json:"channel_id"`
			Participants []json.RawMessage `json:"participants"`
		} `json:"channels"`
	}
	if json.Unmarshal(data, &snapshot) != nil || snapshot.Channels == nil || len(snapshot.Channels) != len(rooms) {
		return errors.New("invalid snapshot room count")
	}
	expected := make(map[string]bool, len(rooms))
	for _, id := range rooms {
		if id == "" || expected[id] {
			return errors.New("invalid expected rooms")
		}
		expected[id] = true
	}
	for _, room := range snapshot.Channels {
		if !expected[room.ID] || room.Participants == nil || len(room.Participants) != 0 {
			return errors.New("unexpected room or participant")
		}
		delete(expected, room.ID)
	}
	return nil
}
