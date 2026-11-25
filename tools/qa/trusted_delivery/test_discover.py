"""Producer discovery never substitutes a foreign, expired or unverified bundle."""
import unittest
from unittest.mock import Mock
from .discover import select

SHA = 'a' * 40


def run(number=42, source=SHA, attempt=1):
    return {'id': number, 'head_sha': source, 'run_attempt': attempt}


class DiscoverTests(unittest.TestCase):
    def test_skips_a_build_without_a_bundle_and_verifies_the_next(self):
        empty = Mock(); empty.collection.return_value = {'artifacts': []}
        kept = Mock(); kept.collection.return_value = {'artifacts': [
            {'name': f'server-{SHA}-42-1', 'expired': False}]}
        factory = lambda number: {'41': empty, '42': kept}[number]
        verified = Mock(return_value={'source_revision': SHA, 'run_id': 42})
        self.assertEqual({'source_revision': SHA, 'run_id': 42},
                         select([run(41), run()], factory, verified))
        verified.assert_called_once_with(kept, 'BOOHTACORD/BOOHTACORD', '42', SHA)

    def test_expired_or_missing_bundles_fail_closed(self):
        reader = Mock(); reader.collection.return_value = {'artifacts': [
            {'name': f'server-{SHA}-42-1', 'expired': True}]}
        with self.assertRaises(ValueError): select([run()], lambda _: reader, Mock())

    def test_existing_bundle_with_failed_authority_never_falls_back(self):
        reader = Mock(); reader.collection.return_value = {'artifacts': [
            {'name': f'server-{SHA}-42-1', 'expired': False}]}
        verified = Mock(side_effect=ValueError('untrusted'))
        with self.assertRaises(ValueError): select([run(), run(43)], lambda _: reader, verified)
        self.assertEqual(1, verified.call_count)

    def test_malformed_producer_identity_is_rejected(self):
        for value in (run(0), run(source='master'), run(attempt=0)):
            with self.subTest(value=value), self.assertRaises(ValueError):
                select([value], Mock(), Mock())
