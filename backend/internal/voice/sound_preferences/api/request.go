package soundapi

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	p "voice-platform/backend/internal/voice/sound_preferences"
)

type patchBody struct {
	ExpectedRevision *int64 `json:"expected_revision"`
	Enabled          *bool  `json:"enabled"`
	Joined           *bool  `json:"joined"`
	Left             *bool  `json:"left"`
	Started          *bool  `json:"started"`
	Stopped          *bool  `json:"stopped"`
	AllowCustom      *bool  `json:"allow_custom"`
	Volume           *int   `json:"volume"`
}
type patch struct {
	patchBody
	Revision int64
}

func decodePatch(w http.ResponseWriter, r *http.Request) (patch, error) {
	var body patchBody
	d := json.NewDecoder(http.MaxBytesReader(w, r.Body, 2048))
	d.DisallowUnknownFields()
	if err := d.Decode(&body); err != nil {
		return patch{}, err
	}
	if err := d.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return patch{}, errors.New("invalid body")
	}
	if body.ExpectedRevision == nil || *body.ExpectedRevision < 0 {
		return patch{}, errors.New("revision required")
	}
	if body.Enabled == nil && body.Joined == nil && body.Left == nil && body.Started == nil && body.Stopped == nil && body.AllowCustom == nil && body.Volume == nil {
		return patch{}, errors.New("no changes")
	}
	return patch{patchBody: body, Revision: *body.ExpectedRevision}, nil
}
func (x patch) apply(s p.Settings) p.Settings {
	if x.Enabled != nil {
		s.Enabled = *x.Enabled
	}
	if x.Joined != nil {
		s.Joined = *x.Joined
	}
	if x.Left != nil {
		s.Left = *x.Left
	}
	if x.Started != nil {
		s.Started = *x.Started
	}
	if x.Stopped != nil {
		s.Stopped = *x.Stopped
	}
	if x.AllowCustom != nil {
		s.AllowCustom = *x.AllowCustom
	}
	if x.Volume != nil {
		s.Volume = *x.Volume
	}
	return s
}
