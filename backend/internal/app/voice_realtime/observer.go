package voicerealtime

import "time"

type Observer interface {
	RosterWSOpened()
	RosterWSClosed()
	ObserveRosterWSDelivery(time.Duration, string, bool)
	ObserveRosterWSRefresh(bool)
}

func (s *stream) observeFrame(elapsed time.Duration, outcome string) {
	if s.observer != nil {
		s.observer.ObserveRosterWSDelivery(elapsed, outcome, s.firstSent.CompareAndSwap(false, true))
	}
}

func (s *stream) ObserveRosterUnavailable(elapsed time.Duration, sent bool) {
	outcome := "failure"
	if sent {
		outcome = "unavailable"
	}
	s.observeFrame(elapsed, outcome)
}
