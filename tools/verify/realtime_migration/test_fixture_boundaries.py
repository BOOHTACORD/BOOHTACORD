import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.verify.realtime_migration.guard import scan


class FixtureBoundariesTest(unittest.TestCase):
    def test_unlisted_test_named_file_does_not_bypass_runtime_guard(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'clients/web/src/stream.test.ts'
            path.parent.mkdir(parents=True)
            path.write_text('new EventSource("/events")\n', encoding='utf8')
            self.assertEqual(scan(root), [('clients/web/src/stream.test.ts', 1)])

    def test_exact_fixture_must_match_reviewed_content(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            name = 'clients/web/src/approved.spec.ts'
            path = root / name
            path.parent.mkdir(parents=True)
            contents = b'new EventSource("/events")\n'
            path.write_bytes(contents)
            with patch('tools.verify.realtime_migration.guard.FIXTURE_HASHES',
                       {name: hashlib.sha256(contents).hexdigest()}, create=True):
                self.assertEqual(scan(root), [])
                path.write_bytes(contents + b'new EventSource("/other")\n')
                self.assertEqual(scan(root), [(name, 1), (name, 2)])
                path.write_text('no legacy markers remain\n', encoding='utf8')
                self.assertEqual(scan(root), [(name, 1)])

    def test_missing_reviewed_fixture_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'clients/web/src').mkdir(parents=True)
            name = 'clients/web/src/approved.spec.ts'
            with patch('tools.verify.realtime_migration.guard.ROOTS', ('clients/web/src',)), \
                    patch('tools.verify.realtime_migration.guard.FIXTURE_HASHES', {name: '0' * 64}):
                self.assertEqual(scan(root, require_roots=True), [(name, 1)])


if __name__ == '__main__':
    unittest.main()
