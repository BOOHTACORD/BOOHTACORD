"""Downloaded ZIP identity is checked before publishing its exact transport pair."""
import hashlib
from io import BytesIO
from pathlib import Path
import tempfile
import unittest
import zipfile
from . import artifact_zip

SOURCE='a'*40


def archive(root, *, extra=None, linked=False, bad_checksum=False):
    path=root/'artifact.zip'; name=SOURCE+'.release.tar.gz'; body=b'signed-bundle-fixture'
    checksum=('0'*64 if bad_checksum else hashlib.sha256(body).hexdigest())+'  '+name+'\n'
    with zipfile.ZipFile(path,'w') as stream:
        if linked:
            row=zipfile.ZipInfo(name); row.create_system=3; row.external_attr=0o120777<<16; stream.writestr(row,body)
        else: stream.writestr(name,body)
        stream.writestr(name+'.sha256',checksum)
        if extra: stream.writestr(extra,b'foreign')
    return path,hashlib.sha256(path.read_bytes()).hexdigest(),path.stat().st_size


class ExactDownloadedZipTests(unittest.TestCase):
    def test_actual_archive_hash_and_bytes_publish_exact_pair(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp).resolve(); path,digest,size=archive(root)
            result=artifact_zip.unpack(path,root/'incoming',SOURCE,'sha256:'+digest,size)
            self.assertEqual('verified',result['outer_digest'])
            self.assertEqual(2,len(list((root/'incoming').iterdir())))

    def test_digest_size_or_source_mismatch_never_publishes_partial_output(self):
        for mutation in ('digest','size','source'):
            with tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp).resolve(); path,digest,size=archive(root)
                with self.assertRaises(ValueError):
                    artifact_zip.unpack(path,root/'incoming','b'*40 if mutation=='source' else SOURCE,
                                        'sha256:'+('0'*64 if mutation=='digest' else digest),size+1 if mutation=='size' else size)
                self.assertFalse((root/'incoming').exists())

    def test_links_traversal_extras_wrong_checksum_or_existing_output_fail(self):
        for mutation in ('link','traversal','extra','checksum','existing'):
            with tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp).resolve()
                path,digest,size=archive(root,linked=mutation=='link',bad_checksum=mutation=='checksum',
                                         extra='../escape' if mutation=='traversal' else 'foreign' if mutation=='extra' else None)
                if mutation=='existing': (root/'incoming').mkdir()
                with self.assertRaises(ValueError): artifact_zip.unpack(path,root/'incoming',SOURCE,'sha256:'+digest,size)
                self.assertFalse((root/'escape').exists())
                self.assertFalse(list(root.glob('.artifact-unpack-*')))

    def test_legacy_missing_digest_is_explicit_and_still_checks_pair(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp).resolve(); path,_,size=archive(root)
            self.assertEqual('unavailable-legacy',artifact_zip.unpack(path,root/'incoming',SOURCE,None,size)['outer_digest'])
