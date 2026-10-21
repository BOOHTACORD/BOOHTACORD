package installationapi

import (
	"crypto/hmac"
	"io"
	"net/http"
	projection "voice-platform/backend/internal/observability/central_projection"
)

// Agent is private-network only and independently authenticated; it grants no
// product access and never forwards caller-supplied identity/tenant headers.
func (h Handler) Agent(w http.ResponseWriter, r *http.Request) {
	if h.Runtime == nil {
		w.WriteHeader(503)
		return
	}
	i := h.Runtime.Identity()
	if i.Valid() != nil || !hmac.Equal([]byte(r.Header.Get("Authorization")), []byte("Bearer "+i.Pseudonym("local-agent", i.ID))) {
		w.WriteHeader(401)
		return
	}
	if r.Header.Get("Content-Encoding") != "" || r.Header.Get("Content-Type") != "application/x-protobuf" {
		w.WriteHeader(415)
		return
	}
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, projection.MaxBytes))
	if err != nil {
		w.WriteHeader(413)
		return
	}
	clean, err := projection.Metrics(raw, i)
	if err != nil {
		w.WriteHeader(400)
		return
	}
	h.Runtime.Enqueue("metrics", clean)
	w.Header().Set("Content-Type", "application/x-protobuf")
	w.WriteHeader(200)
}
