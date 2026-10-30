"""Read one bounded immutable public proof; API ownership and actual ZIP digest are mandatory."""
import hashlib
import json
from pathlib import Path
import re
import stat
import tempfile
import zipfile
from tools.release.delivery import artifact_download
from ..intent import require


def document(api,run,name,member):
    listing=api.read(f'/actions/runs/{run["id"]}/artifacts?per_page=100')
    rows=listing['artifacts'];require(listing['total_count']==len(rows) and len(rows)<=100)
    matches=[row for row in rows if row.get('name')==name];require(len(matches)==1)
    row=matches[0];owner=row.get('workflow_run',{})
    require(type(row.get('id')) is int and row['id']>0 and row.get('expired') is False
        and type(row.get('size_in_bytes')) is int and 0<row['size_in_bytes']<=131072
        and re.fullmatch('sha256:[0-9a-f]{64}',row.get('digest',''))
        and owner.get('id')==run['id'] and owner.get('repository_id')==run['repository']['id']
        and owner.get('head_repository_id')==run['repository']['id']
        and owner.get('head_sha')==run['head_sha'] and owner.get('head_branch')=='master')
    with tempfile.TemporaryDirectory(prefix='promotion-noop-proof-') as directory:
        path=Path(directory)/'proof.zip'
        artifact_download.receive(artifact_download.location(row['id'],api.token),path,row['size_in_bytes'])
        require('sha256:'+hashlib.sha256(path.read_bytes()).hexdigest()==row['digest'])
        with zipfile.ZipFile(path) as archive:
            items=archive.infolist();require(len(items)==1);item=items[0]
            require(item.filename==member and 0<item.file_size<=65536 and not item.flag_bits&1
                and item.compress_type in (zipfile.ZIP_STORED,zipfile.ZIP_DEFLATED)
                and stat.S_IFMT(item.external_attr>>16) in (0,stat.S_IFREG))
            value=json.loads(archive.read(item));require(isinstance(value,dict))
    return value,{'id':row['id'],'name':name,'bytes':row['size_in_bytes'],
                  'sha256':row['digest'][7:],'actual_zip_digest_verified':True}
