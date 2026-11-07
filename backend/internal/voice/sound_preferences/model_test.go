package soundpreferences

import "testing"

func TestListenerConsentPrecedence(t *testing.T) {
	defaults := Default()
	if defaults.Volume < 1 || defaults.Volume > 100 {
		t.Fatal("default volume must be audible and bounded")
	}
	events := []Event{MemberJoined, MemberLeft, StreamStarted, StreamStopped}
	for _, event := range events {
		if !defaults.Allows(event, false) {
			t.Fatalf("default blocks %s", event)
		}
		if defaults.Allows(event, true) {
			t.Fatalf("deafen permits %s", event)
		}
		disabled := defaults
		disabled.Enabled = false
		if disabled.Allows(event, false) {
			t.Fatalf("master OFF permits %s", event)
		}
	}
	if defaults.Allows(Event("unknown"), false) {
		t.Fatal("unknown events must be silent")
	}
	off := defaults
	off.Joined = false
	if off.Allows(MemberJoined, false) || off.AllowsCustomJoin(false) {
		t.Fatal("join OFF must suppress default and custom")
	}
	noCustom := defaults
	noCustom.AllowCustom = false
	if !noCustom.Allows(MemberJoined, false) || noCustom.AllowsCustomJoin(false) {
		t.Fatal("custom OFF must retain default join")
	}
	muted := defaults
	muted.Volume = 0
	if muted.Allows(MemberJoined, false) || muted.AllowsCustomJoin(false) {
		t.Fatal("zero volume must be silent")
	}
}

func TestVolumeValidation(t *testing.T) {
	for _, volume := range []int{-1, 101} {
		s := Default()
		s.Volume = volume
		if s.Validate() == nil {
			t.Fatalf("accepted volume %d", volume)
		}
	}
	for _, volume := range []int{0, 100} {
		s := Default()
		s.Volume = volume
		if s.Validate() != nil {
			t.Fatalf("rejected volume %d", volume)
		}
	}
}

func TestIndependentEventFlags(t *testing.T) {
	for _, test := range []struct {
		name    string
		event   Event
		disable func(*Settings)
	}{
		{"join", MemberJoined, func(s *Settings) { s.Joined = false }},
		{"leave", MemberLeft, func(s *Settings) { s.Left = false }},
		{"start", StreamStarted, func(s *Settings) { s.Started = false }},
		{"stop", StreamStopped, func(s *Settings) { s.Stopped = false }},
	} {
		t.Run(test.name, func(t *testing.T) {
			s := Default()
			test.disable(&s)
			if s.Allows(test.event, false) {
				t.Fatal("disabled event played")
			}
			for _, other := range []Event{MemberJoined, MemberLeft, StreamStarted, StreamStopped} {
				if other != test.event && !s.Allows(other, false) {
					t.Fatalf("disabled unrelated event %s", other)
				}
			}
		})
	}
}
