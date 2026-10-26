package runtimeconfig

import "fmt"

func notificationAvailability(value string) (bool, error) {
	switch value {
	case "", "false":
		return false, nil
	case "true":
		return true, nil
	default:
		return false, fmt.Errorf("NOTIFICATIONS_AVAILABLE must be true or false")
	}
}
