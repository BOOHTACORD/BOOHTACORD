"""Public failure receipts locate the roster outage without retaining private logs."""
from pathlib import Path
import tempfile
import unittest

from .failure_stage import last_failure_stage


class RosterStageTests(unittest.TestCase):
    def test_last_completed_roster_boundary_survives_private_error_details(self):
        stages = ('roster-sfu-paused', 'roster-failure-event-observed',
                  'roster-failure-banner-visible', 'roster-failure-copy-visible',
                  'roster-failure-ui-accepted', 'roster-sfu-restored')
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory)/'private.log'
            for stage in stages:
                with self.subTest(stage=stage):
                    log.write_text('stage=roster-transport-restored\n'
                                   'stage='+stage+'\nprivate credentials and bodies\n'
                                   'stage=unrecognized-private-value\n')
                    self.assertEqual(last_failure_stage(log), stage)
