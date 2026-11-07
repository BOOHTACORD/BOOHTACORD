package soundpreferences

import "errors"

type Event string

const (
	MemberJoined  Event = "voice.member_joined"
	MemberLeft    Event = "voice.member_left"
	StreamStarted Event = "voice.stream_started"
	StreamStopped Event = "voice.stream_stopped"
)

type Settings struct {
	Enabled     bool `json:"enabled"`
	Joined      bool `json:"joined"`
	Left        bool `json:"left"`
	Started     bool `json:"started"`
	Stopped     bool `json:"stopped"`
	AllowCustom bool `json:"allow_custom"`
	Volume      int  `json:"volume"`
}

func Default() Settings {
	return Settings{Enabled: true, Joined: true, Left: true, Started: true, Stopped: true, AllowCustom: true, Volume: 50}
}

func (s Settings) Validate() error {
	if s.Volume < 0 || s.Volume > 100 {
		return errors.New("voice sound volume must be between 0 and 100")
	}
	return nil
}

func (s Settings) Allows(event Event, deafened bool) bool {
	if !s.Enabled || deafened || s.Volume <= 0 || s.Volume > 100 {
		return false
	}
	switch event {
	case MemberJoined:
		return s.Joined
	case MemberLeft:
		return s.Left
	case StreamStarted:
		return s.Started
	case StreamStopped:
		return s.Stopped
	default:
		return false
	}
}

func (s Settings) AllowsCustomJoin(deafened bool) bool {
	return s.AllowCustom && s.Allows(MemberJoined, deafened)
}
