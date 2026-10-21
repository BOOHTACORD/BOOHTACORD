package installationapi

import (
	"encoding/json"
	"io"
	"net/http"
	central "voice-platform/backend/internal/observability/central_export"
	requestid "voice-platform/backend/internal/security/request_id"
)

type Handler struct{ Runtime *central.Runtime }

func (h Handler) snapshot() central.Snapshot {
	if h.Runtime == nil {
		return central.Snapshot{Mode: "local_only", State: "unavailable"}
	}
	return h.Runtime.Snapshot()
}
func write(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
func (h Handler) Public(w http.ResponseWriter, r *http.Request) {
	s := h.snapshot()
	write(w, 200, struct {
		ID    string `json:"installation_id"`
		Mode  string `json:"mode"`
		State string `json:"state"`
	}{s.InstallationID, s.Mode, s.State})
}
func (h Handler) Read(w http.ResponseWriter, r *http.Request) { write(w, 200, h.snapshot()) }
func (h Handler) Patch(w http.ResponseWriter, r *http.Request) {
	if h.Runtime == nil {
		failure(w, r, 503, "TELEMETRY_UNAVAILABLE")
		return
	}
	var input struct {
		Mode      string `json:"mode"`
		Endpoint  string `json:"endpoint"`
		Confirmed bool   `json:"confirmed"`
	}
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 2048))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&input) != nil || decoder.Decode(new(any)) != io.EOF || (input.Mode != "local_only" && input.Mode != "central") || input.Mode == "central" && !input.Confirmed {
		failure(w, r, 400, "INVALID_TELEMETRY_SETTINGS")
		return
	}
	var err error
	if input.Mode == "central" {
		if central.Endpoint(input.Endpoint) != nil {
			failure(w, r, 400, "INVALID_CENTRAL_ENDPOINT")
			return
		}
		err = h.Runtime.Enable(r.Context(), input.Endpoint)
	} else {
		err = h.Runtime.Disable(r.Context())
	}
	if err != nil {
		failure(w, r, 503, "TELEMETRY_CONFIGURATION_FAILED")
		return
	}
	write(w, 200, h.snapshot())
}

func failure(w http.ResponseWriter, r *http.Request, status int, code string) {
	write(w, status, map[string]any{"error": map[string]string{"code": code, "message": "Не удалось изменить телеметрию установки", "request_id": requestid.From(r.Context())}})
}
