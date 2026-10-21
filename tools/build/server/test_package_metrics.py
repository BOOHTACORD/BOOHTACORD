"""Actual tiny OCI artifacts retain signing/packaging with independent timing records."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from tools.release.bundle.package import package
from tools.release.bundle.test_manifest import fixture as manifest_fixture
from tools.release.bundle.verify import verify_bundle
from tools.verify.oci.test_verify_oci import fixture,REVISION,SOURCE_HASH
from tools.verify.oci.verify_oci import verify
from .metrics import Metrics


class SignedPackageMetricsTests(unittest.TestCase):
    def test_real_signature_and_transport_checksum_survive_timing_instrumentation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);bundle=root/REVISION;bundle.mkdir();key=root/'test-key';public=root/'test-public'
            subprocess.run(['openssl','genpkey','-algorithm','RSA','-pkeyopt','rsa_keygen_bits:2048','-out',str(key)],check=True,capture_output=True)
            subprocess.run(['openssl','pkey','-in',str(key),'-pubout','-out',str(public)],check=True,capture_output=True)
            receipts={}
            for name in ('api','web'):
                path=bundle/(name+'.oci.tar');digest=fixture(path);receipts[name]=verify(path,REVISION,SOURCE_HASH,digest)
            (bundle/'runtime.tar.gz').write_bytes(b'isolated tiny unit fixture')
            metrics=Metrics(root/'metrics.json',REVISION)
            archive=package(bundle,REVISION,SOURCE_HASH,receipts,manifest_fixture()['compatibility'],
                            {'source_revision':REVISION,'checks':dict.fromkeys(('backend','web','contracts','artifact_smoke'),'PASS')},
                            key,measure=metrics.stage)
            verify_bundle(bundle,public,REVISION)
            self.assertTrue(archive.is_file());self.assertTrue(Path(str(archive)+'.sha256').is_file())
            value=json.loads((root/'metrics.json').read_text())
            self.assertEqual(['manifest','sign','package'],[r['phase'] for r in value['stages']])
            self.assertNotIn(str(key),json.dumps(value))
