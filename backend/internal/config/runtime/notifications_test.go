package runtimeconfig

import "testing"

func TestNotificationAvailabilityIsExplicit(t *testing.T) {
	for _, test := range []struct {
		value   string
		want    bool
		invalid bool
	}{{"", false, false}, {"false", false, false}, {"true", true, false}, {"yes", false, true}} {
		got, err := notificationAvailability(test.value)
		if got != test.want || (err != nil) != test.invalid {
			t.Fatalf("%q got=%v err=%v", test.value, got, err)
		}
	}
}
