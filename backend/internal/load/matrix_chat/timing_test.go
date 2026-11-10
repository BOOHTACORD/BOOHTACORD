package matrixchat

import (
	"context"
	"testing"
	"time"
)

func TestMixedOrConflictingTimestampsAreRejected(t *testing.T) {
	cases := []struct{ first, second time.Time }{
		{time.Time{}, time.Now()},
		{time.Now(), time.Time{}},
		{time.Now().Add(-time.Millisecond), time.Now()},
	}
	for _, tc := range cases {
		c, _ := New(2)
		start := time.Now().Add(-time.Second)
		if err := c.Begin(start); err != nil {
			t.Fatal(err)
		}
		at := time.Now().Add(time.Second)
		c.ObserveTimed(0, first, at, tc.first)
		c.ObserveTimed(1, first, at, tc.second)
		if _, err := c.FinishDetailed(context.Background(), first); err == nil {
			t.Fatal("invalid timing accepted")
		}
	}
}
