import json
from pathlib import Path
import tempfile
import unittest
from .assets import verify
from .contract import inputs,digest
from .test_contract import fixture

IDENTITY=dict(builder_revision='a'*40,run_id='101',run_attempt='1')


class AssetTests(unittest.TestCase):
    def test_exact_sdk_candidate_and_tamper_fail_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);archive=root/'WebRTC-macos.xcframework.zip';archive.write_bytes(b'synthetic archive metadata fixture')
            row=dict(inputs(),**IDENTITY,architectures=[fixture('arm64'),fixture('x64')],
                     signing='adhoc-framework-not-notarized',physical_playback_smoke='NOT_RUN',xcframework_sha256=digest(archive))
            (root/'sdk-manifest.json').write_text(json.dumps(row));(root/'SHA256SUMS').write_text(digest(archive)+'  '+archive.name+'\n')
            self.assertEqual('PASS',verify(root,IDENTITY)['status'])
            archive.write_bytes(b'tampered')
            with self.assertRaises(ValueError):verify(root,IDENTITY)
