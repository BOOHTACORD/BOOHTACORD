"""Windows archive conversion must not alter the authenticated license delivery."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from . import notices


class NoticeTests(unittest.TestCase):
    def test_windows_crlf_and_unix_sources_deliver_identical_authenticated_bytes(self):
        root = Path(__file__).resolve().parents[3] / 'tools/audio/runtime_assets/deepfilter'
        identity = json.loads((root / 'engine.json').read_text(encoding='utf-8'))
        for ending in (b'\n', b'\r\n'):
            with self.subTest(ending=ending), tempfile.TemporaryDirectory() as temporary:
                source, output = Path(temporary) / 'source', Path(temporary) / 'output'
                source.mkdir(); output.mkdir()
                for name in notices.UPSTREAM:
                    (source / name).write_bytes((root / name).read_bytes().replace(b'\n', ending))
                notices.stage(source, output)
                notices.validate(output)
                for name in notices.UPSTREAM:
                    delivered = (output / ('DeepFilterNet-' + name)).read_bytes()
                    self.assertEqual(hashlib.sha256(delivered).hexdigest(), identity['files'][name])

    def test_altered_upstream_and_cached_notices_are_rejected(self):
        root = Path(__file__).resolve().parents[3] / 'tools/audio/runtime_assets/deepfilter'
        with tempfile.TemporaryDirectory() as temporary:
            source, output = Path(temporary) / 'source', Path(temporary) / 'output'
            source.mkdir(); output.mkdir()
            for name in notices.UPSTREAM:
                (source / name).write_bytes((root / name).read_bytes())
            (source / 'LICENSE-MIT').write_bytes(b'altered notice')
            with self.assertRaisesRegex(ValueError, 'notice'):
                notices.stage(source, output)
            (source / 'LICENSE-MIT').write_bytes((root / 'LICENSE-MIT').read_bytes())
            notices.stage(source, output)
            (output / 'DeepFilterNet-LICENSE').write_bytes(b'cached notice changed')
            with self.assertRaisesRegex(ValueError, 'notice'):
                notices.validate(output)
