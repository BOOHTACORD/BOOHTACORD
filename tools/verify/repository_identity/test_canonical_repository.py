"""Tracked project references use the repository's current organization identity."""
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


class CanonicalRepositoryIdentityTests(unittest.TestCase):
    def test_tracked_files_do_not_reference_the_pre_transfer_repository(self):
        legacy = ('Egkurilov' + '/BOOHTACORD').encode()
        old_github_pages = ('egkurilov' + '.github.io/BOOHTACORD').encode()
        paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).split(b'\0')
        stale = []
        for raw in paths:
            if not raw:
                continue
            path = ROOT / raw.decode()
            try:
                content = path.read_bytes()
            except OSError:
                continue
            lower = content.lower()
            if b'\0' not in content and (legacy in content or old_github_pages in lower):
                stale.append(str(path.relative_to(ROOT)))
        self.assertEqual([], stale, 'Update old repository references: ' + ', '.join(stale))


if __name__ == '__main__':
    unittest.main()
