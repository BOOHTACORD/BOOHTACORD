package run_profile

func finalize(report *Report) {
	if report.Cleanup == "FAIL" {
		report.Outcome = "FAIL"
		report.StopReason = "cleanup_failed"
		return
	}
	for _, status := range report.Criteria {
		if status == "FAIL" {
			if report.Outcome == "PASS" || report.StopReason == "" {
				report.StopReason = "measured_criterion_failed"
			}
			report.Outcome = "FAIL"
			return
		}
	}
}
