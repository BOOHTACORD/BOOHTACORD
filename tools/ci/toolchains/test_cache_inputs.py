import json
from pathlib import Path
import tempfile
import unittest
from .cache_inputs import payload, write_manifest


class CacheInputTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory();self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name).resolve()
        self.versions={'node':'24.18.0','go':'1.26.4','flutter':'3.47.7','dart':'3.13.5'}
        for name,content in {'tools/toolchains.json':json.dumps(self.versions),'.node-version':'24.18.0\n',
                'backend/go.mod':'module fixture\ngo 1.26.0\ntoolchain go1.26.4\n',
                'backend/go.sum':'public module checksum\n','clients/web/package.json':'{}',
                'clients/web/package-lock.json':'{"lockfileVersion":3}','.env':'PRIVATE-CANARY'}.items():
            path=self.root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(content)

    def test_stable_public_manifest_is_the_actual_generated_dependency_file(self):
        result=payload('npm',self.root,'Linux','X64')
        self.assertEqual(result,payload('npm',self.root,'Linux','X64'))
        path=write_manifest('npm',self.root,'Linux','X64')
        self.assertEqual(path,self.root/'.out/ci/cache-inputs/npm.json')
        self.assertEqual(json.loads(path.read_text()),result)
        self.assertNotIn('PRIVATE-CANARY',path.read_text())
        self.assertEqual(set(result['files']),{'.node-version','clients/web/package.json','clients/web/package-lock.json'})

    def test_lock_sdk_os_and_arch_changes_invalidate_real_manifest_bytes(self):
        initial=payload('npm',self.root,'Linux','X64')
        for platform,arch in [('Windows','X64'),('Linux','ARM64')]:
            self.assertNotEqual(initial,payload('npm',self.root,platform,arch))
        path=self.root/'clients/web/package-lock.json';path.write_text('{"lockfileVersion":3,"packages":{}}')
        self.assertNotEqual(initial,payload('npm',self.root,'Linux','X64'))
        path.write_text('{"lockfileVersion":3}')
        self.versions['node']='24.19.0'
        (self.root/'tools/toolchains.json').write_text(json.dumps(self.versions))
        (self.root/'.node-version').write_text('24.19.0\n')
        self.assertNotEqual(initial,payload('npm',self.root,'Linux','X64'))

    def test_go_sum_and_selected_toolchain_invalidate_go_manifest(self):
        initial=payload('go',self.root,'Windows','X64')
        (self.root/'backend/go.sum').write_text('changed dependency checksum')
        self.assertNotEqual(initial,payload('go',self.root,'Windows','X64'))
        (self.root/'backend/go.sum').write_text('public module checksum\n')
        self.versions['go']='1.26.5';(self.root/'tools/toolchains.json').write_text(json.dumps(self.versions))
        (self.root/'backend/go.mod').write_text('module fixture\ngo 1.26.0\ntoolchain go1.26.5\n')
        self.assertNotEqual(initial,payload('go',self.root,'Windows','X64'))

    def test_missing_symlinked_or_drifting_inputs_fail_before_cache_restore(self):
        path=self.root/'.node-version';path.write_text('24.19.0')
        with self.assertRaises(ValueError): payload('npm',self.root,'Linux','X64')
        path.unlink();path.symlink_to(self.root/'.env')
        with self.assertRaises(ValueError): payload('npm',self.root,'Linux','X64')
        path.unlink()
        with self.assertRaises(ValueError): payload('npm',self.root,'Linux','X64')
        for kind,platform,arch in [('unknown','Linux','X64'),('go','foreign','X64'),('go','Linux','unknown')]:
            with self.assertRaises(ValueError): payload(kind,self.root,platform,arch)

    def test_windows_line_endings_and_go_directive_comments_keep_the_approved_sdk(self):
        (self.root/'backend/go.mod').write_bytes(
            b'module fixture\r\ngo 1.26.0 // minimum\r\ntoolchain go1.26.4 // selected\r\n')
        self.assertEqual(payload('go',self.root,'Windows','X64')['toolchain'],'1.26.4')
