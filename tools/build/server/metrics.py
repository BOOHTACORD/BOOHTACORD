"""Actual monotonic build timings, without command output or signing inputs."""
from contextlib import contextmanager
import json
from pathlib import Path
import re
import time


class Metrics:
    def __init__(self,path,revision):
        if not re.fullmatch('[a-f0-9]{40}',revision):raise ValueError('Exact metric source is required')
        self.path=Path(path)
        self.value={'schema_version':1,'source_revision':revision,'status':'RUNNING','stages':[],
                    'cache':{},'upload_timing':'GitHub upload step timestamps; not measured inside builder'}
        self.save()

    def save(self):
        temporary=self.path.with_suffix('.tmp')
        temporary.write_text(json.dumps(self.value,sort_keys=True,indent=2)+'\n');temporary.replace(self.path)

    @contextmanager
    def stage(self,name):
        if not re.fullmatch('[a-z][a-z0-9_-]{0,40}',name):raise ValueError('Invalid build phase')
        row={'phase':name,'status':'FAIL','seconds':0};self.value['stages'].append(row);started=time.monotonic()
        try:
            yield
            row['status']='PASS'
        except BaseException:
            self.value['status']='FAIL';raise
        finally:
            row['seconds']=round(time.monotonic()-started,6);self.save()

    def complete(self,images):
        if not self.value['stages'] or any(r['status']!='PASS' for r in self.value['stages']):raise ValueError('Incomplete build metrics')
        storage=self.value.get('builder_storage')
        if storage is not None and (storage.get('status')!='PASS' or storage.get('owned_resources_removed') is not True):
            raise ValueError('Owned builder storage cleanup is incomplete')
        if set(images)!={'api','web'} or any(not re.fullmatch('sha256:[a-f0-9]{64}',v) for v in images.values()):
            raise ValueError('Verified component digests are required')
        self.value.update(status='PASS',images=images);self.save()
