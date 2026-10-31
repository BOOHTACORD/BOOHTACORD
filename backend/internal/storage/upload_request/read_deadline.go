package uploadrequest

import (
	"net/http"
	"time"
)

type readDeadline struct {
	controller  *http.ResponseController
	maximum, at time.Time
	idle        time.Duration
}

func newReadDeadline(writer http.ResponseWriter, maximum, idle time.Duration) (*readDeadline, error) {
	deadline := &readDeadline{controller: http.NewResponseController(writer), maximum: time.Now().Add(maximum), idle: idle}
	deadline.advance()
	// Check native support before reading. The timer owns expiry classification;
	// a parallel future socket expiry could cancel the parent context first.
	return deadline, deadline.controller.SetReadDeadline(time.Time{})
}

func (deadline *readDeadline) advance() {
	deadline.at = time.Now().Add(deadline.idle)
	if deadline.maximum.Before(deadline.at) {
		deadline.at = deadline.maximum
	}
}

func (deadline *readDeadline) interrupt() { _ = deadline.controller.SetReadDeadline(time.Now()) }
func (deadline *readDeadline) clear()     { _ = deadline.controller.SetReadDeadline(time.Time{}) }
