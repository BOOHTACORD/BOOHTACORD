package relayapi

import (
	"net"
	"net/http"
	"time"
	accept "voice-platform/backend/internal/pushrelay/accept_notification"
	enroll "voice-platform/backend/internal/pushrelay/enroll_device"
	pair "voice-platform/backend/internal/pushrelay/pair_installation"
)

func (h Handler) challenge(w http.ResponseWriter, r *http.Request) {
	var in enroll.Challenge
	if _, err := body(w, r, &in); err != nil {
		failure(w, 400, "INVALID_REQUEST")
		return
	}
	source, _, _ := net.SplitHostPort(r.RemoteAddr)
	out, err := h.Enroll.Challenge(r.Context(), in, source, time.Now().UTC())
	if err != nil {
		writeError(w, err)
		return
	}
	reply(w, 202, out)
}
func (h Handler) verify(w http.ResponseWriter, r *http.Request) {
	var in enroll.Proof
	raw, err := body(w, r, &in)
	if err != nil {
		failure(w, 400, "INVALID_REQUEST")
		return
	}
	out, err := h.Enroll.Verify(r.Context(), signed(r, raw), in, time.Now().UTC())
	if err != nil {
		writeError(w, err)
		return
	}
	reply(w, 200, out)
}
func (h Handler) pair(w http.ResponseWriter, r *http.Request) {
	var in pair.Input
	raw, err := body(w, r, &in)
	if err != nil {
		failure(w, 400, "INVALID_REQUEST")
		return
	}
	out, err := h.Pair.Pair(r.Context(), signed(r, raw), in, time.Now().UTC())
	if err != nil {
		writeError(w, err)
		return
	}
	reply(w, 200, out)
}
func (h Handler) accept(w http.ResponseWriter, r *http.Request) {
	var in accept.Input
	raw, err := body(w, r, &in)
	if err != nil {
		failure(w, 400, "INVALID_REQUEST")
		return
	}
	out, err := h.Accept.Accept(r.Context(), signed(r, raw), in, time.Now().UTC())
	if err != nil {
		writeError(w, err)
		return
	}
	reply(w, 202, out)
}
func (h Handler) status(w http.ResponseWriter, r *http.Request) {
	var in accept.Query
	raw, err := body(w, r, &in)
	if err != nil {
		failure(w, 400, "INVALID_REQUEST")
		return
	}
	out, err := h.Accept.Status(r.Context(), signed(r, raw), in, time.Now().UTC())
	if err != nil {
		writeError(w, err)
		return
	}
	reply(w, 200, out)
}
func (h Handler) revoke(w http.ResponseWriter, r *http.Request) {
	var in struct{}
	raw, err := body(w, r, &in)
	if err != nil {
		failure(w, 400, "INVALID_REQUEST")
		return
	}
	request := signed(r, raw)
	if id := r.PathValue("grantID"); id != "" {
		err = h.Revoke.Revoke(r.Context(), request, id, time.Now().UTC())
	} else if r.PathValue("deviceID") == request.Subject {
		err = h.Revoke.Device(r.Context(), request, time.Now().UTC())
	} else {
		failure(w, 404, "NOT_FOUND")
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(204)
}
