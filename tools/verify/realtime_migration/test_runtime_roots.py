import tempfile
import unittest
from pathlib import Path

from tools.verify.realtime_migration.guard import scan


class RuntimeRootsTest(unittest.TestCase):
    def test_all_first_party_entrypoints_reject_streams(self):
        names = (
            'backend/cmd/server/stream.go',
            'clients/web/public/worker.js',
            'clients/web/scripts/stream.mjs',
            'clients/flutter/native/stream.cpp',
            'clients/flutter/ios/ScreenShareExtension/stream.swift',
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in names:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('"text/event-stream"', encoding='utf8')
            self.assertEqual({name for name, _ in scan(root)}, set(names))


if __name__ == '__main__':
    unittest.main()
