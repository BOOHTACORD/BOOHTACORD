"""The notice index must describe physical archive paths on Windows and Unix."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from zipfile import ZipFile
from .collect import collect
from .test_collect import metadata


class NoticePathTests(unittest.TestCase):
    def test_nested_license_directory_preserves_physical_case_without_aliases(self):
        for spelling in ('LICENSES', 'licenses', 'LiCeNsEs'):
            with self.subTest(spelling=spelling), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                data = metadata(root)
                directory = root / 'crate' / spelling
                directory.mkdir()
                (directory / 'Apache-2.0.txt').write_bytes(b'Original Apache notice')
                (directory / 'MIT.txt').write_bytes(b'Original MIT copyright')
                output = root / 'notices'
                report = collect(data, output)
                notices = report['entries'][0]['notices']
                self.assertEqual(set(notices), {spelling + '/Apache-2.0.txt', spelling + '/MIT.txt'})
                self.assertEqual(report['noticeFiles'], 2)
                archive = root / 'notices.zip'
                with ZipFile(archive, 'w') as packaged:
                    for file in output.rglob('*'):
                        if file.is_file():
                            packaged.write(file, file.relative_to(output).as_posix())
                with ZipFile(archive) as packaged:
                    for name, expected in notices.items():
                        actual = packaged.read('example-1.0.0/' + name)
                        self.assertEqual(hashlib.sha256(actual).hexdigest(), expected)
