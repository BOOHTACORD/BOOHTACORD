package main

import (
	"errors"
	"io"
	"net/http"
	"strings"
	"time"
)

type faultTransport struct {
	state *state
	base  http.RoundTripper
}

func (t faultTransport) RoundTrip(r *http.Request) (*http.Response, error) {
	record, mode := t.state.consume(r.URL.Path)
	public := strings.HasPrefix(mode, "public-")
	mode = strings.TrimPrefix(mode, "public-")
	if mode == "upgrade-error" {
		record.finish(false)
		return nil, errors.New("owned upgrade failure")
	}
	if mode == "session-late401" {
		r.Header.Del("Cookie")
		r.URL.Path = "/api/v1/channels"
	}
	response, err := t.base.RoundTrip(r)
	if err != nil || mode == "" {
		return response, err
	}
	record.response(response.StatusCode)
	delay := time.Duration(0)
	if mode == "upgrade-stall" || mode == "session-stall" {
		delay = 20 * time.Second
	}
	if mode == "split-budget" {
		delay = 10 * time.Second
		if public {
			delay = 2 * time.Second
		}
	}
	if mode == "session-late401" {
		// Deliberately attempt the actual API401 after the client's cancellation.
		timer := time.NewTimer(12 * time.Second)
		<-timer.C
		record.finish(r.Context().Err() != nil)
		return response, nil
	}
	if delay > 0 && !wait(r.Context(), delay) {
		_ = response.Body.Close()
		record.finish(true)
		return nil, r.Context().Err()
	}
	if mode == "ready-stall" || mode == "split-budget" {
		stream, ok := response.Body.(io.ReadWriteCloser)
		if !ok || response.StatusCode != 101 {
			_ = response.Body.Close()
			return nil, errors.New("owned upgrade missing")
		}
		response.Body = &delayedBody{ReadWriteCloser: stream, ctx: r.Context(), sample: record}
	} else {
		record.finish(false)
	}
	return response, nil
}
