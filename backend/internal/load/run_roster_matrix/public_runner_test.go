package runrostermatrix

import (
	"context"
	"testing"

	"voice-platform/backend/internal/load/validate_target"
)

func TestPublicRunnerRejectsForeignTargetsAndUnboundedCounts(t *testing.T) {
	for _, guests := range []int{0, 1, 101} {
		report := RunPublic(context.Background(), validate_target.Manifest{Origin: "https://foreign.invalid"}, "candidate", guests)
		if report.Outcome != "FAIL" || report.StopReason != "preflight" {
			t.Fatal("unsafe public fixture accepted")
		}
	}
}
