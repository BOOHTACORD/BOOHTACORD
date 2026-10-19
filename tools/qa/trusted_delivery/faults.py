"""Actual bounded SSH/SCP, immutable, downgrade and HTTPS readback negatives."""
import json
from pathlib import Path
import re
import secrets
import subprocess
from tools.qa.compatible_rollback.storage import observe, running
from tools.release.delivery.receipt import checked
from tools.release.delivery.readback_contract import validate as acknowledgement
from tools.release.bundle.files import sha256
from tools.release.install import observation, readback
from tools.release.install.locking import installation_lock
from .positive import attempt, stop
from .variant import variant

EXPECTED={'ssh-refused':('current_revision','exit'),'scp-timeout':('transfer_bundle','timeout'),
          'immutable':('remote_install','exit'),'downgrade':('history','exit')}


def require_failure(name, value):
    value=checked(value)
    if name not in EXPECTED or value['status']!='FAIL' or not value['phases']:
        raise ValueError('A failed actual negative attempt is required')
    last=value['phases'][-1]
    if last['status']!='FAIL' or (last['phase'],last['failure_code'])!=EXPECTED[name]:
        raise ValueError('Actual negative failed at another guard')


def cleanup_attempt(work, name):
    import pwd
    plan=json.loads((work/'private'/('attempt-'+name+'.json')).read_text())
    nonce=plan['nonce']; source=plan['source']
    if not re.fullmatch('[a-f0-9]{32}',nonce) or not re.fullmatch('[a-f0-9]{40}',source): raise ValueError('Invalid owned stage')
    stage=Path('/tmp/voice-platform-delivery-'+nonce)
    if not stage.exists(): return
    if (stage.is_symlink() or not stage.is_dir() or stage.stat().st_uid!=pwd.getpwnam('operator').pw_uid
            or stage.stat().st_mode&0o777!=0o700): raise ValueError('Refusing foreign transport stage')
    allowed={source+'.release.tar.gz',source+'.installer.tar.gz'}
    rows=list(stage.iterdir())
    if any(p.name not in allowed or p.is_symlink() or not p.is_file() or p.stat().st_nlink!=1 for p in rows):
        raise ValueError('Refusing unexpected transport stage entries')
    for path in rows:path.unlink()
    stage.rmdir()


def health_failure(work, source, controller):
    public=work/'trusted-signing.pub.pem'; root=work/'releases'; directory=root/source
    with installation_lock(root): readback.fresh(root,source,public)
    receipt_sha=sha256(directory/'installed.json')
    api=observation.container('api')
    subprocess.run(['docker','pause',api],check=True,capture_output=True)
    probe_failed=ack_failed=False
    try:
        try: observation.health(directory)
        except Exception: probe_failed=True
        try:
            with installation_lock(root): readback.fresh(root,source,public)
        except Exception: ack_failed=True
        if not probe_failed or not ack_failed: raise RuntimeError('Unavailable HTTPS service produced health or acknowledgement PASS')
    finally: subprocess.run(['docker','unpause',api],check=True,capture_output=True)
    with installation_lock(root): fresh=readback.fresh(root,source,public)
    if sha256(directory/'installed.json')!=receipt_sha: raise RuntimeError('Read-only health negative changed installed receipt')
    nonce=secrets.token_hex(16)
    fresh={**fresh,'controller_revision':controller,'nonce':nonce}
    raw=json.dumps(fresh).encode()
    acknowledgement(raw,source,controller,fresh['previous_source_revision'],nonce)
    try: acknowledgement(raw,source,controller,fresh['previous_source_revision'],secrets.token_hex(16))
    except ValueError: pass
    else: raise RuntimeError('Another attempt nonce accepted the actual fresh readback')
    return {'health_failure':'EXPECTED_FAIL','fresh_ack_failure':'EXPECTED_FAIL','health_restored':'PASS',
            'installed_receipt_unchanged':True,'foreign_nonce':'EXPECTED_FAIL','scope':'Actual paused QA API and HTTPS probe; no failed rollout or production outage claimed'}


def run(work, report):
    baseline=observe('negative-guard'); images=running('negative-guard')
    archive=work/'negative'/(report['next']+'.release.tar.gz')
    from tools.release.bundle.verify import verify_bundle
    verify_bundle(work/'negative'/report['next'],work/'trusted-signing.pub.pem',report['next'])
    progress={'status':'RUNNING','attempts':[]}
    def save(): (work/'negative-runtime.json').write_text(json.dumps(progress,indent=2)+'\n')
    try:
        results=[]
        for name in EXPECTED:
            source=report['baseline'] if name=='downgrade' else report['next']
            process=attempt(work,name,source,report['controller'],archive=archive if name=='immutable' else None)
            try:
                code=process.wait(timeout=900)
            finally: stop(process)
            value=checked(json.loads((work/('attempt-'+name+'.json')).read_text()))
            progress['attempts'].append({'name':name,'delivery':value})
            save()
            if code==0:raise RuntimeError('Actual negative unexpectedly succeeded')
            require_failure(name,value)
            if value['source_revision']!=source or value['controller_revision']!=report['controller']:
                raise RuntimeError('Actual negative receipt belongs to another source/controller')
            if name=='immutable':
                command=['python3','-m','tools.release.install.run',str(archive),source,sha256(archive),
                         '--expected-current-revision',report['next']]
                output=subprocess.run(command,cwd='/qa/controller',capture_output=True,timeout=180)
                if output.returncode==0 or b'Immutable release directory contains another artifact' not in output.stdout+output.stderr:
                    raise RuntimeError('Valid-signature mismatch did not reach the intended immutable guard')
            if observe('negative-guard')!=baseline or running('negative-guard')!=images:
                raise RuntimeError('Actual negative changed persistent data or running source')
            cleanup_attempt(work,name)
            results.append({'name':name,'status':'EXPECTED_FAIL','delivery':value,
                            'state_unchanged':True,'fault':'real bandwidth-limited SCP with one-second local deadline' if name=='scp-timeout' else name})
        health=health_failure(work,report['next'],report['controller'])
        if observe('negative-guard')!=baseline or running('negative-guard')!=images:
            raise RuntimeError('Actual health negative changed persistent data or running source')
        progress['status']='PASS'
        return {'status':'PASS','transport':results,'health_readback':health,
                'scope':'Owned real failures; no production mutation or claim that interrupting SSH stops remote Docker'}
    finally:
        if progress['status']!='PASS':progress['status']='FAIL'
        save()
