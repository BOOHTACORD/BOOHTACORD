import hashlib
import io
import json
import stat
import unittest
import zipfile
from .test_support import API,execute


class ProofArchiveTests(unittest.TestCase):
    def test_valid_digest_does_not_bypass_closed_archive_members_and_json_shape(self):
        for identity in (123,456):
            for mutation in ('extra','path','symlink','oversized','compression','encrypted','json','list','truncated'):
                api=API();row=api.rows[identity][0];member='route.json' if identity==456 else 'master-server.json'
                output=io.BytesIO()
                with zipfile.ZipFile(output,'w') as archive:
                    name='../'+member if mutation=='path' else member
                    item=zipfile.ZipInfo(name)
                    if mutation=='symlink':item.create_system=3;item.external_attr=(stat.S_IFLNK|0o777)<<16
                    if mutation=='compression':item.compress_type=zipfile.ZIP_BZIP2
                    value=json.dumps(api.route if identity==456 else api.quality)
                    if mutation=='list':value='[]'
                    if mutation=='json':value='invalid'
                    if mutation=='oversized':value+=' '*(65537-len(value))
                    archive.writestr(item,value)
                    if mutation=='extra':archive.writestr('unexpected.json','{}')
                raw=output.getvalue()
                if mutation=='encrypted':
                    raw=bytearray(raw);raw[6]|=1;raw[raw.index(b'PK\x01\x02')+8]|=1;raw=bytes(raw)
                if mutation=='truncated':raw=raw[:-10]
                api.blobs[row['id']]=raw;row['size_in_bytes']=len(raw)
                row['digest']='sha256:'+hashlib.sha256(raw).hexdigest()
                with self.subTest(identity=identity,mutation=mutation):
                    trace,_,endpoints=execute(api)
                    self.assertEqual(trace['status'],'FAIL')
                    self.assertEqual(trace['failure_stage'],'deployment')
                    self.assertEqual(endpoints,0)
