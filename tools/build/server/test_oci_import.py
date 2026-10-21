"""An ambiguous export cannot reach Docker's OCI importer."""
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from tools.verify.oci.test_verify_oci import fixture, REVISION, SOURCE_HASH
from tools.verify.oci.verify_oci import verify
from .oci_import import oci_root_identity


def exported(path):
    identity,_=fixture(path)
    with tarfile.open(path) as archive:
        rows=[(item,archive.extractfile(item).read()) for item in archive]
    result=[]
    for item,raw in rows:
        if item.name=='index.json':
            value=json.loads(raw);value['schemaVersion']=2;raw=json.dumps(value).encode()
        result.append((item.name,raw,None))
    result.append(('oci-layout',b'{"imageLayoutVersion":"1.0.0"}',None))
    write(path,result)
    return identity,result


def write(path,rows):
    with tarfile.open(path,'w') as archive:
        for name,raw,kind in rows:
            item=tarfile.TarInfo(name);item.size=len(raw)
            if kind is not None:item.type=kind
            archive.addfile(item,io.BytesIO(raw))


class OciImportTests(unittest.TestCase):
    def test_real_export_shape_still_requires_the_full_source_and_attestation_verifier(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'image.tar';identity,_=exported(path)
            self.assertEqual(identity,oci_root_identity(path))
            self.assertEqual(identity,verify(path,REVISION,SOURCE_HASH,identity)['index_digest'])

    def test_duplicate_members_links_and_outside_paths_are_rejected(self):
        for mutation in ('duplicate','link','outside'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp:
                path=Path(tmp)/'image.tar';_,rows=exported(path)
                extra=rows[0] if mutation=='duplicate' else ('unexpected-link',b'',tarfile.SYMTYPE) if mutation=='link' else ('../outside',b'x',None)
                write(path,rows+[extra])
                with self.assertRaises(ValueError):oci_root_identity(path)

    def test_duplicate_json_keys_and_invalid_layout_are_rejected(self):
        for mutation in ('json','layout'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp:
                path=Path(tmp)/'image.tar';_,rows=exported(path)
                changed=[]
                for name,raw,kind in rows:
                    if mutation=='json' and name=='index.json':raw=b'{"schemaVersion":1,'+raw[1:]
                    if mutation=='layout' and name=='oci-layout':raw=b'{"imageLayoutVersion":"0.0.0"}'
                    changed.append((name,raw,kind))
                write(path,changed)
                with self.assertRaises(ValueError):oci_root_identity(path)
