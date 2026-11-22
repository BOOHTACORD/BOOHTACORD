package connectsession

import (
	"encoding/binary"
	"time"
)

// The digest is used only to spread schedules; it is never emitted or stored.
func sessionMonitorFirstDelay(digest [32]byte, interval time.Duration) time.Duration {
	if interval <= 0 {
		return 0
	}
	if digest == [32]byte{} {
		return interval
	}
	return time.Duration(binary.BigEndian.Uint64(digest[:8]) % uint64(interval))
}
