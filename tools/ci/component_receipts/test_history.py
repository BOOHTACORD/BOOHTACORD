"""Receipt history cannot substitute a different source, run, profile or future attempt."""
from pathlib import Path
import tempfile
import unittest
from .history import archive_pattern, select_archives, valid_attempt


class HistoryTests(unittest.TestCase):
    def test_selects_latest_attempt_per_profile_without_requiring_peers_to_repeat(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            for profile, attempt in [('dart', '1'), ('android', '1'), ('android', '2')]:
                (root / ('flutter-part-flutter-' + 'a' * 40 + '-123-' + attempt + '-' + profile)).mkdir()
            selected = select_archives(root, ['dart', 'android'], '2', archive_pattern('flutter', 'a' * 40, '123'))
            self.assertEqual({p: row[1] for p, row in selected.items()}, {'dart': '1', 'android': '2'})

    def test_foreign_source_run_unknown_profile_future_and_missing_profile_fail(self):
        for case in ('source', 'run', 'profile', 'future', 'missing', 'file'):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary).resolve()
                source, run, profile, attempt = 'a' * 40, '123', 'dart', '1'
                if case == 'source': source = 'b' * 40
                if case == 'run': run = '124'
                if case == 'profile': profile = 'macos'
                if case == 'future': attempt = '3'
                path = root / ('flutter-part-flutter-' + source + '-' + run + '-' + attempt + '-' + profile)
                if case == 'file': path.write_bytes(b'not a directory')
                else: path.mkdir()
                selected = ['dart', 'android'] if case == 'missing' else ['dart']
                with self.assertRaises(ValueError):
                    select_archives(root, selected, '2', archive_pattern('flutter', 'a' * 40, '123'))

    def test_attempts_have_a_canonical_bounded_execution_identity(self):
        for value in ('0', '02', '-1', '3', 2, None):
            with self.subTest(value=value), self.assertRaises(ValueError): valid_attempt(value, '2')
        self.assertEqual(valid_attempt('1', '2'), '1')
