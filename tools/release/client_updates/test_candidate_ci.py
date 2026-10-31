import json
import unittest
from subprocess import CompletedProcess
from unittest.mock import Mock

from tools.release.client_updates.candidate_ci import dispatch_and_wait


class CandidateCITests(unittest.TestCase):
    branch = "codex/windows-catalog-windows-v1.0.39-123"
    sha = "a" * 40

    def test_dispatches_and_waits_for_matching_candidate_run(self):
        runs = [{"databaseId": 7, "headSha": "b" * 40, "headBranch": self.branch,
                 "event": "workflow_dispatch"},
                {"databaseId": 8, "headSha": self.sha, "headBranch": self.branch,
                 "event": "workflow_dispatch"}]
        status = {"databaseId": 8, "headSha": self.sha, "headBranch": self.branch,
                  "event": "workflow_dispatch", "status": "completed", "conclusion": "success"}
        command = Mock(side_effect=[CompletedProcess([], 0),
            CompletedProcess([], 0, json.dumps(runs)), CompletedProcess([], 0, json.dumps(status))])

        url = dispatch_and_wait(self.branch, self.sha, "BOOHTACORD/BOOHTACORD",
                                command=command, sleep=lambda _: None)

        self.assertEqual(url, "https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/8")
        self.assertEqual(command.call_args_list[0].args[0],
                         ["gh", "workflow", "run", "ci.yaml", "--ref", self.branch,
                          "--repo", "BOOHTACORD/BOOHTACORD"])
        self.assertIn(self.sha, command.call_args_list[1].args[0])
        self.assertEqual(command.call_args_list[2].args[0][3], "8")

    def test_failed_dispatch_stops_before_any_run_watch(self):
        command = Mock(return_value=CompletedProcess([], 1, "", "forbidden"))
        with self.assertRaisesRegex(RuntimeError, "actions:write.*no PR"):
            dispatch_and_wait(self.branch, self.sha, "BOOHTACORD/BOOHTACORD", command=command)
        command.assert_called_once()

    def test_ci_failure_stops_before_pr_with_run_link(self):
        run = {"databaseId": 9, "headSha": self.sha, "headBranch": self.branch,
               "event": "workflow_dispatch"}
        status = {"databaseId": 9, "headSha": self.sha, "headBranch": self.branch,
                  "event": "workflow_dispatch", "status": "completed", "conclusion": "failure"}
        command = Mock(side_effect=[CompletedProcess([], 0),
            CompletedProcess([], 0, json.dumps([run])), CompletedProcess([], 0, json.dumps(status))])
        with self.assertRaisesRegex(RuntimeError, "CI did not pass.*actions/runs/9.*no PR"):
            dispatch_and_wait(self.branch, self.sha, "BOOHTACORD/BOOHTACORD", command=command)

    def test_missing_exact_sha_run_fails_closed(self):
        command = Mock(side_effect=[CompletedProcess([], 0), CompletedProcess([], 0, "[]")])
        with self.assertRaisesRegex(RuntimeError, "No CI run.*no PR"):
            dispatch_and_wait(self.branch, self.sha, "BOOHTACORD/BOOHTACORD",
                              command=command, sleep=lambda _: None, registration_attempts=1)
        self.assertEqual(command.call_count, 2)


if __name__ == "__main__":
    unittest.main()
