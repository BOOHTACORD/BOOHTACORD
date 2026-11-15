from pathlib import Path
import tempfile
import unittest
from .verify_rebuild import verify, ROOT


class SourceRebuildTests(unittest.TestCase):
    def test_compares_all_runtime_bytes_with_the_delivery_identity(self):
        assets = ROOT / 'tools/audio/runtime_assets'
        verify(assets / 'rnnoise', assets / 'deepfilter')
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            (output / 'rnnoise.wasm').write_bytes(b'changed compiler output')
            with self.assertRaisesRegex(ValueError, 'rnnoise/rnnoise.wasm'):
                verify(output, assets / 'deepfilter')
