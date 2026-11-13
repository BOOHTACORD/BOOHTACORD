package run_profile

import (
	"testing"
	"voice-platform/backend/internal/load/record_results"
)

func TestCleanupAndMeasuredCriteriaCannotReportSuccess(t *testing.T) {
	for _, report := range []Report{{Outcome: "PASS", Cleanup: "FAIL"}, {Outcome: "PASS", Cleanup: "PASS", Criteria: map[string]string{"message": "FAIL"}}} {
		finalize(&report)
		if report.Outcome != "FAIL" {
			t.Fatal("false successful report")
		}
	}
	report := Report{Outcome: "PASS", Cleanup: "PASS", Criteria: criteria(map[string]record_results.Summary{})}
	finalize(&report)
	if report.Outcome != "PASS" || report.Criteria["message_ws_p95_500ms"] != "NOT_RUN" {
		t.Fatal(report)
	}
	rows := map[string]record_results.Summary{"fanout": {Count: 100, P95MS: 501}}
	report.Criteria = criteria(rows)
	finalize(&report)
	if report.Outcome != "FAIL" {
		t.Fatal("p95 breach did not fail")
	}
}

func TestMeasuredFailureDoesNotEraseEarlierStopReason(t *testing.T) {
	report := Report{Outcome: "FAIL", StopReason: "guard_resource_stop", Cleanup: "PASS", Criteria: map[string]string{"message": "FAIL"}}
	finalize(&report)
	if report.StopReason != "guard_resource_stop" || report.Outcome != "FAIL" {
		t.Fatal(report)
	}
}
