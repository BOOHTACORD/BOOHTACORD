import tempfile
import unittest
from pathlib import Path
from .runtime import retain_runtime

class RuntimeTests(unittest.TestCase):
    def test_only_the_official_x64_redist_folder_is_copied(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);vs=root/'Visual Studio Пример'
            crt=vs/'VC/Redist/MSVC/14.44.1/x64/Microsoft.VC143.CRT';crt.mkdir(parents=True)
            for name in ['msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll']:(crt/name).write_bytes(b'fixture')
            destination=root/'release';destination.mkdir()
            retain_runtime(destination,visual_studio=vs)
            self.assertEqual({p.name for p in destination.glob('*.dll')},{'msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll'})
    def test_missing_runtime_stops_packaging(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            with self.assertRaisesRegex(RuntimeError,'redistributable'):retain_runtime(root,visual_studio=root/'missing')
