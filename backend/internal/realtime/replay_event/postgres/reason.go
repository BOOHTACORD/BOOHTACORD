package replayeventpostgres

func allowedReason(value any) bool {
	reason, ok := value.(string)
	if !ok {
		return false
	}
	switch reason {
	case "TRANSFER", "KICK", "CHANNEL_CLOSED", "SESSION_REVOKED", "BANNED", "LOGOUT", "VOLUNTARY_LEAVE", "AFK_MOVE":
		return true
	default:
		return false
	}
}
