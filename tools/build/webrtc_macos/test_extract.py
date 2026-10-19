from pathlib import Path
import stat
import tempfile
import unittest
import zipfile
from .extract import extract


class FrameworkArchiveTests(unittest.TestCase):
    def archive(self,path,link,extra=False):
        with zipfile.ZipFile(path,'w') as stream:
            stream.writestr('WebRTC.framework/Versions/A/WebRTC',b'Mach-O fixture')
            row=zipfile.ZipInfo('WebRTC.framework/WebRTC');row.external_attr=(stat.S_IFLNK|0o777)<<16;stream.writestr(row,link)
            if extra:stream.writestr('WebRTC.framework/WebRTC/overwrite',b'no')

    def test_framework_internal_version_link(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory).resolve();self.archive(root/'a.zip','Versions/A/WebRTC')
            framework=extract(root/'a.zip',root/'output');self.assertEqual(b'Mach-O fixture',(framework/'WebRTC').read_bytes())

    def test_escape_and_symlink_parent_cannot_write_outside(self):
        for link,extra in [('../../secret',False),('Versions/A/WebRTC',True)]:
            with tempfile.TemporaryDirectory() as directory,self.subTest(link=link):
                root=Path(directory).resolve();self.archive(root/'a.zip',link,extra)
                with self.assertRaises(ValueError):extract(root/'a.zip',root/'output')
