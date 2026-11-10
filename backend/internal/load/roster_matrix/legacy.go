package rostermatrix

import (
	"bufio"
	"encoding/json"
	"errors"
	"io"
	"strings"
	"time"
)

// ReadLegacy exists solely for comparison with the isolated pre-cutover server.
func ReadLegacy(reader io.Reader, stream string, rooms []string, started time.Time, observe func(string, time.Duration)) error {
	if stream != "roster" && stream != "maintenance" {
		return errors.New("unknown legacy fixture stream")
	}
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 4096), 512<<10)
	event, data := "", ""
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "event:") {
			event = strings.TrimSpace(strings.TrimPrefix(line, "event:"))
		} else if strings.HasPrefix(line, "data:") {
			if data != "" {
				return errors.New("unexpected multiline fixture event")
			}
			data = strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		} else if line == "" {
			if event == "roster-unavailable" || event == "session-expired" {
				return errors.New("legacy fixture stream unavailable")
			}
			if data != "" {
				if stream == "roster" {
					if err := ValidateEmptySnapshot([]byte(data), rooms); err != nil {
						return err
					}
				} else {
					var state struct {
						Active *bool `json:"active"`
					}
					if json.Unmarshal([]byte(data), &state) != nil || state.Active == nil {
						return errors.New("unknown maintenance state")
					}
					if *state.Active {
						observe("maintenance_change", time.Since(started))
						data, event = "", ""
						continue
					}
				}
				observe(stream, time.Since(started))
			}
			event, data = "", ""
		}
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	return io.ErrUnexpectedEOF
}
