package preferencesapi

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	p "voice-platform/backend/internal/notifications/preferences"
)

func strictBody(w http.ResponseWriter, r *http.Request, destination any) error {
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 64<<10))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(destination); err != nil {
		return p.ErrInvalid
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return p.ErrInvalid
	}
	return nil
}
func decodeInput(w http.ResponseWriter, r *http.Request, importing bool) (p.Input, error) {
	input := p.Input{Import: importing}
	if importing {
		var body struct {
			ExpectedRevision *int64       `json:"expected_revision"`
			Overrides        []p.Override `json:"overrides"`
			LocalDisabled    bool         `json:"local_disabled"`
		}
		if err := strictBody(w, r, &body); err != nil || body.ExpectedRevision == nil {
			return input, p.ErrInvalid
		}
		input.ExpectedRevision = *body.ExpectedRevision
		input.Settings = p.Default()
		input.Settings.Overrides = body.Overrides
	} else {
		var body struct {
			ExpectedRevision *int64     `json:"expected_revision"`
			Settings         p.Settings `json:"settings"`
		}
		if err := strictBody(w, r, &body); err != nil || body.ExpectedRevision == nil {
			return input, p.ErrInvalid
		}
		input.ExpectedRevision = *body.ExpectedRevision
		input.Settings = body.Settings
	}
	return input, nil
}
