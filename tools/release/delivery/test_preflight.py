"""Artifact authority must survive the download, including producer reruns."""
import unittest
from unittest.mock import Mock
from .test_producer_artifacts import fixtures, REPO, SHA
from . import test_routing
from . import preflight


def reader(run=None, artifacts=None):
    original, document = fixtures()
    fixture = test_routing.ProducerRoutingTests(); fixture.setUp(); fixture.modern()
    value = Mock()
    value.read.side_effect = [run or original, run or original]
    value.collection.side_effect = [fixture.jobs, artifacts or document]
    return value


class DownloadAuthorityTests(unittest.TestCase):
    def test_preflight_and_revalidation_preserve_the_complete_artifact_identity(self):
        accepted = preflight.verified(reader(), REPO, '123', SHA)
        self.assertEqual(44, accepted['id'])
        self.assertEqual('sha256:' + 'b' * 64, accepted['digest'])
        self.assertEqual(accepted, preflight.verified(reader(), REPO, '123', SHA, expected=accepted))

    def test_same_sha_replacement_or_rerun_during_download_is_rejected(self):
        baseline = preflight.verified(reader(), REPO, '123', SHA)
        for field, value in [('id', 45), ('size_in_bytes', 101), ('digest', 'sha256:' + 'c' * 64)]:
            run, artifacts = fixtures(); artifacts['artifacts'][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                preflight.verified(reader(run, artifacts), REPO, '123', SHA, expected=baseline)
        run, artifacts = fixtures(attempt=3)
        with self.assertRaises(ValueError):
            preflight.verified(reader(run, artifacts), REPO, '123', SHA, expected=baseline)

    def test_rerun_between_metadata_reads_or_missing_identity_does_not_verify(self):
        original, _ = fixtures(); value = reader()
        value.read.side_effect = [original, {**original, 'run_attempt': 3}]
        with self.assertRaises(ValueError): preflight.verified(value, REPO, '123', SHA)
        for invalid in (None, {}, {'id': 44}, {'private': 'canary'}):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                preflight.verified(reader(), REPO, '123', SHA, expected=invalid)

    def test_extra_snapshot_fields_are_not_silently_accepted(self):
        accepted = preflight.verified(reader(), REPO, '123', SHA)
        with self.assertRaises(ValueError):
            preflight.verified(reader(), REPO, '123', SHA, expected={**accepted, 'unused': True})
