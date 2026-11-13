import io
import tarfile
import tempfile
import unittest
import subprocess
from pathlib import Path
from .run import extract
from . import run


class ArchiveTests(unittest.TestCase):
    def test_baseline_archives_shared_contracts_from_that_exact_revision(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in ('clients/web/index.html', 'contracts/client-build.json',
                             'contracts/screen-share-profile-v1.catalog.json', 'backend/private.txt'):
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('{}', encoding='utf-8')
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=QA', '-c',
                    'user.email=qa@example.invalid', *args], cwd=root).decode().strip()
            git('init', '--quiet')
            git('add', 'clients', 'contracts', 'backend')
            git('commit', '--quiet', '-m', 'historical baseline')
            historical = git('rev-parse', 'HEAD')
            fixture = root / 'contracts/voice-sound-pcm.fixtures.json'
            fixture.write_text('{"joined":"shared-pcm"}', encoding='utf-8')
            stage = root / 'tools/audio/research_dfn_web/stage.mjs'
            stage.parent.mkdir(parents=True)
            stage.write_text('export const fixture = true', encoding='utf-8')
            (stage.parent / 'private.txt').write_text('not included', encoding='utf-8')
            git('add', 'contracts', 'tools')
            git('commit', '--quiet', '-m', 'shared sound fixtures')
            current = git('rev-parse', 'HEAD')
            for revision, expected in ((historical, False), (current, True)):
                with tarfile.open(fileobj=io.BytesIO(run.archive_source(root, revision))) as archive:
                    names = archive.getnames()
                    self.assertEqual(expected, 'contracts/voice-sound-pcm.fixtures.json' in names)
                    self.assertEqual(expected, 'tools/audio/research_dfn_web/stage.mjs' in names)
                    self.assertNotIn('backend/private.txt', names)
                    self.assertNotIn('tools/audio/research_dfn_web/private.txt', names)
                    self.assertIn('contracts/client-build.json', names)

    def test_rejects_escape(self):
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w') as archive:
            entry = tarfile.TarInfo('../escape')
            archive.addfile(entry)
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                extract(stream.getvalue(), Path(directory))

    def test_rejects_links_outside_source(self):
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w') as archive:
            entry = tarfile.TarInfo('clients/web/link')
            entry.type, entry.linkname = tarfile.SYMTYPE, '/etc/passwd'
            archive.addfile(entry)
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                extract(stream.getvalue(), Path(directory))
