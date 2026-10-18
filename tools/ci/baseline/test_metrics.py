import unittest

from .metrics import duration_seconds, percentile, summarize_workflow_runs


class MetricsTests(unittest.TestCase):
    def test_percentile_uses_nearest_rank_and_ignores_missing_values(self):
        values = [10, None, 20, 30, 40]
        self.assertEqual(percentile(values, 0.50), 20)
        self.assertEqual(percentile(values, 0.95), 40)
        self.assertIsNone(percentile([None], 0.95))

    def test_duration_rejects_missing_or_reversed_timestamps(self):
        self.assertEqual(
            duration_seconds("2026-10-18T10:00:00Z", "2026-10-18T10:00:05Z"),
            5,
        )
        self.assertIsNone(duration_seconds(None, "2026-10-18T10:00:05Z"))
        self.assertIsNone(
            duration_seconds("2026-10-18T10:00:05Z", "2026-10-18T10:00:00Z")
        )

    def test_artifact_steps_recognize_upload_retain_and_download_action_names(self):
        summary = summarize_workflow_runs(
            [
                {
                    "status": "completed",
                    "conclusion": "success",
                    "jobs": [
                        {
                            "status": "completed",
                            "conclusion": "success",
                            "steps": [
                                {"name": "Upload Flutter navigation actual"},
                                {"name": "Retain the exact verified release"},
                                {"name": "Run actions/download-artifact@v4"},
                            ],
                        }
                    ],
                }
            ]
        )
        self.assertEqual(summary["artifact_upload_step_count"], 2)
        self.assertEqual(summary["artifact_download_step_count"], 1)

    def test_summary_counts_cancelled_work_but_excludes_in_progress_from_green_latency(self):
        runs = [
            {
                "status": "completed",
                "conclusion": "success",
                "run_started_at": "2026-10-18T10:00:00Z",
                "completed_at": "2026-10-18T10:01:00Z",
                "jobs": [
                    {
                        "status": "completed",
                        "conclusion": "success",
                        "started_at": "2026-10-18T10:00:00Z",
                        "completed_at": "2026-10-18T10:01:00Z",
                        "steps": [
                            {
                                "status": "completed",
                                "conclusion": "success",
                                "started_at": "2026-10-18T10:00:20Z",
                                "completed_at": "2026-10-18T10:00:50Z",
                            }
                        ],
                    }
                ],
            },
            {
                "status": "completed",
                "conclusion": "cancelled",
                "run_started_at": "2026-10-18T10:02:00Z",
                "completed_at": "2026-10-18T10:03:30Z",
                "jobs": [
                    {
                        "status": "completed",
                        "conclusion": "cancelled",
                        "started_at": "2026-10-18T10:02:00Z",
                        "completed_at": "2026-10-18T10:03:30Z",
                        "steps": [],
                    }
                ],
            },
            {
                "status": "in_progress",
                "conclusion": None,
                "run_started_at": "2026-10-18T10:04:00Z",
                "completed_at": None,
                "jobs": [
                    {
                        "status": "in_progress",
                        "conclusion": None,
                        "started_at": "2026-10-18T10:04:00Z",
                        "completed_at": None,
                        "steps": [],
                    }
                ],
            },
            {
                "status": "completed",
                "conclusion": "success",
                "run_started_at": "2026-10-18T10:05:00Z",
                "completed_at": None,
                "jobs": [
                    {
                        "status": "completed",
                        "conclusion": "success",
                        "started_at": None,
                        "completed_at": None,
                        "steps": [],
                    }
                ],
            },
        ]

        summary = summarize_workflow_runs(runs)

        self.assertEqual(summary["status_counts"]["in_progress"], 1)
        self.assertEqual(summary["conclusion_counts"]["cancelled"], 1)
        self.assertEqual(summary["successful_run_elapsed_seconds"]["count"], 1)
        self.assertEqual(
            summary["successful_run_elapsed_seconds"]["p50"], 60
        )
        self.assertEqual(summary["runner_minutes_total"], 2.5)
        self.assertEqual(summary["missing_job_timing_count"], 1)


if __name__ == "__main__":
    unittest.main()
