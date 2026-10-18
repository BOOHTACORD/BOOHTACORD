import unittest

from .report import build_report, render_markdown


def workflow_run(jobs):
    return {
        "run_id": "1",
        "url": "https://example.invalid/runs/1",
        "status": "completed",
        "conclusion": "success",
        "jobs": [
            {
                "name": name,
                "status": "completed",
                "conclusion": "success",
                "duration_seconds": duration,
                "steps": [],
            }
            for name, duration in jobs
        ],
    }


class ReportTests(unittest.TestCase):
    def test_hotspots_and_repeated_master_jobs_come_from_measured_rows(self):
        report = build_report(
            {
                "sample_size_requested": 2,
                "history": {},
                "populations": {
                    "pr_required_gate": [
                        workflow_run(
                            [("custom / alpha", 120), ("quick / check", 60)]
                        )
                    ],
                    "master_ci": [
                        workflow_run(
                            [("api / backend", 90), ("site / frontend", 80)]
                        )
                    ],
                    "master_build_server": [
                        workflow_run(
                            [("api / backend", 100), ("site / frontend", 95)]
                        )
                    ],
                },
            },
            "example/repository",
        )

        markdown = render_markdown(report)

        self.assertIn("custom / alpha (p95 2.00 min)", markdown)
        self.assertIn("quick / check (p95 1.00 min)", markdown)
        self.assertIn("both ran backend, frontend jobs", markdown)
        self.assertNotIn("Windows (p95", markdown)


if __name__ == "__main__":
    unittest.main()
