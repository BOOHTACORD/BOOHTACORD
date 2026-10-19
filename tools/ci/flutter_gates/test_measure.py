"""Measurements use bounded current-run artifacts and read-only metadata only."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from . import measure
from .test_comparison import fixtures


class MeasureTests(unittest.TestCase):
    def test_only_exact_nine_source_run_attempt_directories_are_accepted(self):
        run, _, _, old, new = fixtures()
        with tempfile.TemporaryDirectory() as name:
            root = Path(name).resolve()
            for sample in (1, 2, 3):
                directory = root / f'flutter-legacy-shadow-old-{sample}-{run["head_sha"]}-123-1'
                directory.mkdir(); (directory / 'flutter-legacy.json').write_text(json.dumps(old[sample - 1]))
                for part in new[sample - 1]:
                    directory = root / f'flutter-part-shadow-new-{sample}-{run["head_sha"]}-123-1-{part["profile"]}'
                    directory.mkdir(); (directory / (part['profile'] + '.json')).write_text(json.dumps(part))
            before, after = measure.read_inputs(root, run['head_sha'], '123', '1')
            self.assertEqual((3, 3), (len(before), len(after)))
            (root / 'foreign-run').mkdir()
            with self.assertRaises(ValueError): measure.read_inputs(root, run['head_sha'], '123', '1')

    def test_missing_or_failed_inputs_replace_stale_comparison_success(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name).resolve(); path = root / '.out/ci/flutter-shadow.json'
            path.parent.mkdir(parents=True); path.write_text('{"status":"PASS"}')
            with patch.object(measure, 'ROOT', root), \
                 patch.object(measure.source, 'context', return_value=('a' * 40, '123', '1', 'shadow-compare')), \
                 patch.object(measure.source, 'verify'), \
                 patch.dict('os.environ', FLUTTER_SHADOW_NEEDS='{"legacy":{"result":"failure"},"profiles":{"result":"success"}}'):
                with self.assertRaises(ValueError): measure.main()
            self.assertEqual('FAIL', json.loads(path.read_text())['status'])

    def test_no_gain_is_retained_and_cannot_exit_successfully(self):
        run, jobs, needs, old, new = fixtures()
        with tempfile.TemporaryDirectory() as name:
            root = Path(name).resolve()
            with patch.object(measure, 'ROOT', root), \
                 patch.object(measure.source, 'context', return_value=('a' * 40, '123', '1', 'shadow-compare')), \
                 patch.object(measure.source, 'verify'), patch.object(measure, 'read_inputs', return_value=(old, new)), \
                 patch.object(measure, 'read_api', side_effect=[run, jobs]), \
                 patch.object(measure.comparison, 'compare', return_value={'status': 'NO_GAIN'}), \
                 patch.dict('os.environ', FLUTTER_SHADOW_NEEDS=json.dumps(needs)):
                with self.assertRaises(SystemExit): measure.main()
            self.assertEqual('NO_GAIN', json.loads((root / '.out/ci/flutter-shadow.json').read_text())['status'])

    def test_api_failure_hides_token_error_body_and_forbids_other_endpoints(self):
        error = HTTPError('https://api.github.com/', 403, 'PRIVATE-CANARY', {}, None)
        with patch.dict('os.environ', GITHUB_TOKEN='TOKEN-CANARY'), \
             patch.object(measure, 'urlopen', side_effect=error), self.assertRaises(RuntimeError) as caught:
            measure.read_api('/actions/runs/123')
        self.assertNotIn('TOKEN-CANARY', str(caught.exception)); self.assertNotIn('PRIVATE-CANARY', str(caught.exception))
        with self.assertRaises(ValueError): measure.read_api('/../another-repo')
