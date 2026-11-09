import tempfile
import unittest
from pathlib import Path

from tools.verify.realtime_migration.guard import scan


class MigrationGuardTest(unittest.TestCase):
    def test_finds_first_party_runtime_streams_but_not_tests_or_exact_fixture(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            files = {
                'clients/web/src/demo.ts': 'new EventSource("/events")',
                'clients/flutter/lib/demo.dart': "voiceRosterEvents()",
                'backend/internal/voice/example.go': '"text/event-stream"',
                'backend/internal/load/roster_matrix/open_legacy.go': '"text/event-stream"',
                'backend/internal/voice/example_test.go': '"text/event-stream"',
                'tools/qa/feature/test_check.py': 'EventSource',
                'tools/qa/feature/example.test.mjs': 'EventSource',
            }
            for name, data in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(data, encoding='utf8')
            result = scan(root)
            self.assertEqual({row[0] for row in result}, {
                'clients/web/src/demo.ts', 'clients/flutter/lib/demo.dart', 'backend/internal/voice/example.go'})

    def test_similar_path_does_not_inherit_legacy_exception(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'backend/internal/load/roster_matrix/new_legacy.go'
            path.parent.mkdir(parents=True)
            path.write_text('"/api/v1/maintenance/events"', encoding='utf8')
            self.assertEqual(len(scan(root)), 1)

    def test_rejects_legacy_writer_and_server_sent_event_implementations(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'backend/internal/voice/new_stream.go'
            path.parent.mkdir(parents=True)
            path.write_text('writeSSEHeaders()\nnewRosterWriter()\nserver-sent-events', encoding='utf8')
            self.assertEqual(len(scan(root)), 3)

    def test_rejects_case_variants_of_legacy_transport_markers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'clients/web/src/stream.ts'
            path.parent.mkdir(parents=True)
            path.write_text('"TEXT/EVENT-STREAM"\n"/MAINTENANCE/EVENTS"', encoding='utf8')
            self.assertEqual(len(scan(root)), 2)

    def test_covers_native_platform_code_and_web_module_variants(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            files = ['clients/web/src/example.tsx', 'clients/web/src/example.cjs',
                     'clients/web/artifacts/design-v2/reference.mjs',
                     'clients/flutter/android/app/src/main/kotlin/Stream.kt',
                     'clients/flutter/ios/Runner/Stream.swift',
                     'clients/flutter/macos/Runner/Stream.swift',
                     'clients/flutter/windows/runner/stream.cpp']
            for name in files:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('"text/event-stream"', encoding='utf8')
            self.assertEqual({p for p, _ in scan(root)}, set(files))

    def test_cli_scope_cannot_silently_omit_required_roots(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                scan(Path(directory), require_roots=True)
