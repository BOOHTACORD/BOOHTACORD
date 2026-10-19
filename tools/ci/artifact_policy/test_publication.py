"""Packaging keeps current mandatory evidence and failure status without raw fallback."""
import json
import tempfile
import unittest
from pathlib import Path
from . import capture_inventory as inventory, captures, publication
from .test_captures import PNG, identity


class CapturePublicationTests(unittest.TestCase):
    def fixture(self, root):
        current = identity(); inventory.begin(root, current)
        capture = root / '.out/issue342/browser/case'; capture.mkdir(parents=True)
        (capture / 'frame.png').write_bytes(PNG)
        part = inventory.part_path(root, current); part.parent.mkdir(parents=True)
        report = {'source_revision': current['source_revision'], 'profile': current['profile'],
                  'status': 'PASS', 'execution': {k: current[k] for k in ('run_id', 'run_attempt', 'namespace')}}
        part.write_text(json.dumps(report))
        return current, part, capture

    def test_current_successful_captures_restore_with_storage_and_test_verdicts_distinct(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); current, _, _ = self.fixture(root)
            package = publication.finish(root, current, 'success')
            value = captures.verify(package, current)
            self.assertEqual({'issue342/browser/case/frame.png', 'capture-publication.json'}, set(value['files']))
            restored = root / 'restored'; captures.restore(package, restored, current)
            report = json.loads((restored / 'capture-publication.json').read_text())
            self.assertEqual('success', report['upstream_status'])
            self.assertEqual('PASS', report['profile_status'])
            self.assertEqual('PASS', value['integrity'])

    def test_missing_partial_or_foreign_success_part_never_creates_upload_directory(self):
        for change in ('missing', 'failed', 'source', 'attempt', 'no-frames'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); current, part, directory = self.fixture(root)
                report = json.loads(part.read_text())
                if change == 'missing': part.unlink()
                elif change == 'no-frames': (directory / 'frame.png').unlink()
                else:
                    if change == 'failed': report['status'] = 'FAIL'
                    if change == 'source': report['source_revision'] = 'b' * 40
                    if change == 'attempt': report['execution']['run_attempt'] = '2'
                    part.write_text(json.dumps(report))
                with self.assertRaises(ValueError): publication.finish(root, current, 'success')
                self.assertFalse(publication.destination(root, current).exists())

    def test_failure_without_part_still_retains_bounded_diagnostics_and_optional_frames(self):
        for frames in (False, True):
            with self.subTest(frames=frames), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); current, part, directory = self.fixture(root); part.unlink()
                if not frames: (directory / 'frame.png').unlink()
                package = publication.finish(root, current, 'failure')
                restored = root / 'restored'; captures.restore(package, restored, current)
                report = json.loads((restored / 'capture-publication.json').read_text())
                self.assertEqual(('failure', 'UNAVAILABLE'), (report['upstream_status'], report['profile_status']))
                self.assertEqual(int(frames), report['capture_files'])

    def test_sensitive_json_never_uses_raw_capture_fallback_or_leaves_partial_publication(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); current, _, directory = self.fixture(root)
            (directory / 'unsafe.json').write_text('{"token":"private-canary"}')
            with self.assertRaises(ValueError) as error: publication.finish(root, current, 'failure')
            self.assertNotIn('private-canary', str(error.exception))
            self.assertFalse(publication.destination(root, current).exists())

    def test_existing_publication_directory_is_never_reused_or_removed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); current, _, _ = self.fixture(root)
            package = publication.finish(root, current, 'success')
            before = (package / 'artifact-manifest.json').read_bytes()
            with self.assertRaises(ValueError): publication.finish(root, current, 'failure')
            self.assertEqual(before, (package / 'artifact-manifest.json').read_bytes())

    def test_flutter_payloads_must_match_the_mandatory_profile_measurements(self):
        import hashlib
        from tools.ci.flutter_gates.artifacts import VISUALS
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); current = {**identity(), 'component': 'flutter', 'profile': 'dart', 'namespace': 'flutter'}
            inventory.begin(root, current)
            directory = root / '.out/visual/flutter'; directory.mkdir(parents=True)
            measured = {'bytes': len(PNG), 'sha256': hashlib.sha256(PNG).hexdigest()}
            for name in VISUALS: (directory / name).write_bytes(PNG)
            part = inventory.part_path(root, current); part.parent.mkdir(parents=True)
            report = {**{k: current[k] for k in ('source_revision', 'profile', 'run_id', 'run_attempt', 'namespace')},
                      'status': 'PASS', 'artifacts': dict.fromkeys(VISUALS, measured)}
            part.write_text(json.dumps(report))
            (directory / VISUALS[0]).write_bytes(PNG + b'changed')
            with self.assertRaises(ValueError): publication.finish(root, current, 'success')
            (directory / VISUALS[0]).write_bytes(PNG)
            package = publication.finish(root, current, 'success')
            manifest = captures.verify(package, current)
            self.assertEqual(set(VISUALS) | {'capture-publication.json'}, set(manifest['files']))
