"""Installer outputs must be withheld until route, ownership and attempt agree."""
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from . import provenance
from .test_producer_artifacts import fixtures, REPO, SHA
from . import test_routing


class ProducerPreflightTests(unittest.TestCase):
    def setUp(self):
        self.run, self.artifacts = fixtures()
        fixture = test_routing.ProducerRoutingTests(); fixture.setUp(); fixture.modern()
        self.jobs = fixture.jobs
        self.env = {'GITHUB_REPOSITORY': REPO, 'BUILD_RUN_ID': '123', 'GITHUB_TOKEN': 'private-token'}

    def invoke(self, output, run_after=None):
        with patch.dict(os.environ, {**self.env, 'GITHUB_OUTPUT': str(output)}, clear=True), \
             patch('tools.release.delivery.api.Reader.read', side_effect=[self.run, run_after or self.run]), \
             patch('tools.release.delivery.api.Reader.collection', side_effect=[self.jobs, self.artifacts]):
            provenance.main()

    def test_exact_source_current_attempt_artifact_is_the_only_download_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'output'; self.invoke(output)
            values = dict(line.split('=', 1) for line in output.read_text().splitlines())
        self.assertEqual(SHA, values['revision'])
        self.assertEqual('123', values['run_id'])
        self.assertEqual('2', values['run_attempt'])
        self.assertEqual(f'server-{SHA}-123-2', values['artifact_name'])
        self.assertEqual('44', values['artifact_id'])

    def test_no_output_for_missing_failed_foreign_stale_or_no_release_evidence(self):
        for mutation in ('missing', 'failed', 'foreign', 'attempt', 'no-release', 'requested-source'):
            self.setUp()
            if mutation == 'missing': self.artifacts.update(total_count=0, artifacts=[])
            if mutation == 'failed': self.jobs['jobs'][1]['conclusion'] = 'failure'
            if mutation == 'foreign': self.artifacts['artifacts'][0]['workflow_run']['id'] = 999
            if mutation == 'attempt': self.artifacts['artifacts'][0]['name'] = f'server-{SHA}-123-1'
            if mutation == 'requested-source': self.env['REQUESTED_REVISION'] = 'c' * 40
            if mutation == 'no-release':
                for index in (1, 2, 4):
                    row = self.jobs['jobs'][index]
                    row.update(name=row['name'].split(' / ')[0], conclusion='skipped')
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp:
                output = Path(tmp) / 'output'
                with self.assertRaises(ValueError): self.invoke(output)
                self.assertFalse(output.exists())

    def test_rerun_started_during_preflight_invalidates_output(self):
        for change in ({'run_attempt': 3}, {'status': 'in_progress'}, {'conclusion': 'cancelled'}):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as tmp:
                output = Path(tmp) / 'output'
                with self.assertRaises(ValueError): self.invoke(output, {**self.run, **change})
                self.assertFalse(output.exists())

    def test_existing_trusted_legacy_bundle_keeps_exact_original_name(self):
        self.run, self.artifacts = fixtures(False)
        fixture = test_routing.ProducerRoutingTests(); fixture.setUp(); self.jobs = fixture.jobs
        self.artifacts['artifacts'][0]['digest'] = None
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'output'; self.invoke(output)
            values = dict(line.split('=', 1) for line in output.read_text().splitlines())
        self.assertEqual(f'server-{SHA}', values['artifact_name'])
