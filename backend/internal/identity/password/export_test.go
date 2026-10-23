package password

import (
	"sync/atomic"
	"testing"
)

// Test-only instrumentation keeps the real Go Argon2id implementation. Callers
// run sequentially; startup initialization is outside the observed interval.
func CountDerivationsForTest(t testing.TB) func() int64 {
	t.Helper()
	original := deriveKey
	var count atomic.Int64
	deriveKey = func(password, salt []byte, time, memory uint32, threads uint8, length uint32) []byte {
		count.Add(1)
		return original(password, salt, time, memory, threads, length)
	}
	t.Cleanup(func() { deriveKey = original })
	return count.Load
}

func CorruptDummyForTest(t testing.TB) {
	t.Helper()
	original := dummyHash
	dummyHash = "synthetic invalid hash"
	t.Cleanup(func() { dummyHash = original })
}
