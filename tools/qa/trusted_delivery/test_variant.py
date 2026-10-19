"""The immutable-mismatch negative remains fully signed with identical OCI inputs."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from tools.release.bundle.package import package
from tools.release.bundle.verify import verify_bundle
from tools.release.bundle.test_manifest import fixture as manifest_fixture
from tools.verify.oci.test_verify_oci import fixture as oci_fixture, REVISION, SOURCE_HASH
from tools.verify.oci.verify_oci import verify
from .variant import variant


class SignedVariantTests(unittest.TestCase):
    def test_distinct_valid_manifest_does_not_change_original_source_images_or_runtime(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); original=root/'original'/REVISION; original.mkdir(parents=True)
            key, public = root/'qa-key.pem', root/'qa-public.pem'
            subprocess.run(['openssl','genpkey','-algorithm','RSA','-pkeyopt','rsa_keygen_bits:2048','-out',str(key)],check=True,capture_output=True)
            subprocess.run(['openssl','pkey','-in',str(key),'-pubout','-out',str(public)],check=True,capture_output=True)
            receipts={}
            for name in ('api','web'):
                path=original/(name+'.oci.tar'); index=oci_fixture(path)
                receipts[name]=verify(path,REVISION,SOURCE_HASH,index)
            (original/'runtime.tar.gz').write_bytes(b'unit-only signed runtime bytes')
            package(original,REVISION,SOURCE_HASH,receipts,manifest_fixture()['compatibility'],
                    {'source_revision':REVISION,'checks':dict.fromkeys(('backend','web','contracts','artifact_smoke'),'PASS')},key)
            before={p.name:p.read_bytes() for p in original.iterdir()}
            target=root/'negative'/REVISION; target.parent.mkdir()
            archive=variant(original,target,key,public,REVISION)
            first=verify_bundle(original,public,REVISION); second=verify_bundle(target,public,REVISION)
            self.assertNotEqual(first,second)
            self.assertEqual(first['components'],second['components'])
            self.assertEqual(first['compatibility'],second['compatibility'])
            self.assertEqual(first['files']['runtime.tar.gz'],second['files']['runtime.tar.gz'])
            self.assertNotEqual(first['files']['checks.json'],second['files']['checks.json'])
            self.assertEqual(json.loads(before['checks.json']),json.loads((target/'checks.json').read_bytes()))
            self.assertEqual(before,{p.name:p.read_bytes() for p in original.iterdir()})
            self.assertTrue(archive.is_file())
