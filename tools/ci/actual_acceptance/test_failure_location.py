"""Keep a finite owned source location, never private stack paths or error text."""
from pathlib import Path
import tempfile
import unittest

from .failure_stage import last_failure_frame


class FailureLocationTests(unittest.TestCase):
    def test_only_first_owned_frame_after_the_last_completed_stage_is_retained(self):
        for prefix in ('/home/private/project/', 'C:\\private\\project\\'):
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory)/'private.log'
                path.write_text('at media (tools/qa/critical_client_acceptance/media.mjs:1:1)\n'
                    'stage=roster-sfu-restored\nError: private token and message\n'
                    f' at rosterOutage ({prefix}tools/qa/critical_client_acceptance/roster_outage.mjs:40:5)\n'
                    ' at media (tools/qa/critical_client_acceptance/media.mjs:78:46)\n')
                self.assertEqual(last_failure_frame(path), {'file': 'roster_outage.mjs', 'line': 40})

    def test_unknown_locations_and_out_of_range_lines_are_not_published(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'private.log'
            path.write_text('stage=roster-sfu-restored\n'
                ' at secret (/private/account-name/unknown.mjs:9:2)\n'
                ' at bad (tools/qa/critical_client_acceptance/media.mjs:9999999:2)\n')
            self.assertIsNone(last_failure_frame(path))
            self.assertIsNone(last_failure_frame(None))
