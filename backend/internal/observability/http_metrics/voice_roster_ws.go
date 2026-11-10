package httpmetrics

import "time"

func (recorder *Recorder) RosterWSOpened() { recorder.rosterWS.Open() }
func (recorder *Recorder) RosterWSClosed() { recorder.rosterWS.Close() }
func (recorder *Recorder) ObserveRosterWSDelivery(elapsed time.Duration, outcome string, initial bool) {
	recorder.rosterWS.Delivery(elapsed, outcome, initial)
}
func (recorder *Recorder) ObserveRosterWSRefresh(success bool) { recorder.rosterWS.Refresh(success) }
