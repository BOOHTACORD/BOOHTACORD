"""Synthetic capture discovery is finite and cannot follow private filesystem data."""
import tempfile
import unittest
from pathlib import Path
from . import capture_inventory
from .test_captures import PNG, identity


class CaptureInventoryTests(unittest.TestCase):
    def test_only_reviewed_web_roots_are_collected_with_original_upload_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            allowed = root / '.out/issue342/browser/case'; allowed.mkdir(parents=True)
            (allowed / 'screen.png').write_bytes(PNG)
            (allowed / 'result.json').write_text('{"status":"PASS"}')
            private = root / '.out/private'; private.mkdir()
            (private / 'session.json').write_text('{"token":"private-canary"}')
            files, ignored = capture_inventory.collect(root, 'web')
            self.assertEqual({'issue342/browser/case/screen.png', 'issue342/browser/case/result.json'}, set(files))
            self.assertEqual(0, ignored)

    def test_flutter_inventory_is_exact_mandatory_set_on_success(self):
        from tools.ci.flutter_gates.artifacts import VISUALS
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); directory = root / '.out/visual/flutter'; directory.mkdir(parents=True)
            for name in VISUALS: (directory / name).write_bytes(PNG)
            files, _ = capture_inventory.collect(root, 'flutter')
            self.assertEqual(set(VISUALS), set(files))
            capture_inventory.complete('flutter', files)
            files.pop(VISUALS[0])
            with self.assertRaises(ValueError): capture_inventory.complete('flutter', files)

    def test_failure_partial_frames_survive_but_logs_traces_and_error_bodies_do_not_publish(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); directory = root / '.out/issue342/browser/case'; directory.mkdir(parents=True)
            (directory / 'failure.png').write_bytes(PNG)
            for name in ('error-context.md', 'console.log', 'trace.zip', '.env'):
                (directory / name).write_text('private-canary')
            files, ignored = capture_inventory.collect(root, 'web')
            self.assertEqual({'issue342/browser/case/failure.png'}, set(files))
            self.assertEqual(4, ignored)

    def test_hidden_files_and_directories_keep_the_original_upload_exclusion_boundary(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); directory = root / '.out/issue342/browser/case'; directory.mkdir(parents=True)
            (directory / 'frame.png').write_bytes(PNG)
            (directory / '.last-run.json').write_text('{"status":"passed"}')
            hidden = directory / '.private'; hidden.mkdir(); (hidden / 'body.json').write_text('{"body":"private-canary"}')
            files, ignored = capture_inventory.collect(root, 'web')
            self.assertEqual({'issue342/browser/case/frame.png'}, set(files))
            self.assertEqual(2, ignored)

    def test_linked_root_directory_or_file_is_rejected_without_following(self):
        for kind in ('root', 'directory', 'file'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); private = root / 'private'; private.mkdir()
                (private / 'screen.png').write_bytes(PNG)
                allowed = root / '.out/issue342/browser'; allowed.parent.mkdir(parents=True)
                if kind == 'root': allowed.symlink_to(private, target_is_directory=True)
                else:
                    allowed.mkdir()
                    (allowed / ('nested' if kind == 'directory' else 'screen.png')).symlink_to(
                        private if kind == 'directory' else private / 'screen.png', target_is_directory=(kind == 'directory'))
                with self.assertRaises(ValueError): capture_inventory.collect(root, 'web')

    def test_freshness_marker_refuses_existing_outputs_and_different_execution(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            capture_inventory.begin(root, identity())
            with self.assertRaises(ValueError): capture_inventory.begin(root, identity())
            changed = {**identity(), 'run_attempt': '2'}
            with self.assertRaises(ValueError): capture_inventory.started(root, changed)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); output = root / '.out/issue342/browser'; output.mkdir(parents=True)
            with self.assertRaises(ValueError): capture_inventory.begin(root, identity())
            self.assertTrue(output.exists())
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); part = root / '.out/ci/web-parts/browser-shell.json'
            part.parent.mkdir(parents=True); part.write_text('{}')
            with self.assertRaises(ValueError): capture_inventory.begin(root, identity())

    def test_unstarted_or_modified_marker_cannot_claim_fresh_owned_fixture(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            with self.assertRaises(ValueError): capture_inventory.started(root, identity())
            marker = capture_inventory.begin(root, identity())
            capture_inventory.started(root, identity())
            marker.write_text('{"status":"PASS"}')
            with self.assertRaises(ValueError): capture_inventory.started(root, identity())

    def test_workflow_paths_and_collector_share_one_exact_inventory(self):
        from tools.ci.web_suites.workflow import CAPTURES
        self.assertEqual(CAPTURES, {'.out/' + name + '/**' for name in capture_inventory.WEB_ROOTS})

    def test_directory_and_ignored_file_walk_is_bounded_too(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); directory = root / '.out/issue342/browser'; directory.mkdir(parents=True)
            for number in range(4): (directory / str(number)).mkdir()
            with patch.object(capture_inventory, 'MAX_ENTRIES', 3), self.assertRaises(ValueError):
                capture_inventory.collect(root, 'web')
