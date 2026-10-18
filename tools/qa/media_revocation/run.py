"""Current-source seven-action POC-03; no production data or media mocks."""
import hashlib
import json
import os
import platform
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from tools.audio.livekit_fixture import IMAGE
from tools.qa.local_features.process import run_owned
from .stack import Stack
from .evidence import validate


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    root=Path(__file__).resolve().parents[3]
    output=root/'.out/issue59/runtime';output.mkdir(parents=True,exist_ok=True)
    if any(output.iterdir()):
        archive=output.parent/('attempt-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
        output.rename(archive);output.mkdir()
    report={'issue':59,'status':'RUNNING','started_at':datetime.now(timezone.utc).isoformat(),
            'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
            'host':platform.platform(),'livekit_image':IMAGE,'actual_api':True,'actual_sfu':True,
            'media_transport_mocks':False,'phase':'stack setup','owned_resources_removed':False,
            'qa_source_sha256':{p.name:digest(p) for p in Path(__file__).parent.iterdir() if p.suffix in ('.py','.mjs','.js')},
            'production_caddy_sha256':digest(root/'deploy/caddy/Caddyfile'),
            'sdk_sha256':digest(root/'clients/web/node_modules/livekit-client/dist/livekit-client.umd.js')}
    report['sdk_version']=json.loads((root/'clients/web/node_modules/livekit-client/package.json').read_text())['version']
    report['backend_tree']=subprocess.check_output(['git','rev-parse','HEAD:backend'],cwd=root,text=True).strip()
    receipt=output/'runtime.json'
    def save():receipt.write_text(json.dumps(report,indent=2)+'\n')
    save()
    try:
        with tempfile.TemporaryDirectory(prefix='qa59-',dir=root/'.out') as work:
            stack=Stack(root,Path(work))
            try:
                stack.start()
                report['sfu_image_id']=subprocess.check_output(['docker','inspect',stack.owner+'-sfu','--format','{{.Image}}'],text=True).strip()
                report['container_images']={role:json.loads(subprocess.check_output(['docker','inspect',stack.owner+'-'+role,'--format','{{json .}}'],text=True))['Image'] for role in ('api','db','proxy','sfu','tempo')}
                ca=Path(work)/'ca.crt'
                subprocess.run(['docker','cp',stack.owner+'-proxy:/data/caddy/pki/authorities/local/root.crt',str(ca)],check=True,stdout=subprocess.DEVNULL)
                inputs=Path(work)/'private.json';inputs.write_text(json.dumps({'owner':stack.owner,'password':stack.password,'directory':str(output),'ca':str(ca)}));inputs.chmod(0o600)
                report['phase']='real browser media';save()
                run_owned(['node',str(Path(__file__).with_name('scenario.mjs'))],cwd=root,
                    env=dict(os.environ,QA_INPUT=str(inputs),QA_RESULT=str(output/'scenario.json')),timeout=900)
                scenario=json.loads((output/'scenario.json').read_text());report.update(scenario)
                if report['status']!='PASS':raise RuntimeError('Real media acceptance incomplete')
                validate(scenario)
            finally:
                stack.close();report['owned_resources_removed']=True
    except Exception as error:
        report.update(status='FAIL',error_type=type(error).__name__)
        raise
    finally:
        report.update(completed_at=datetime.now(timezone.utc).isoformat(),screenshots={p.name:digest(p) for p in output.glob('*.png')});save()
    print('POC-03 PASS: seven actual-media revocations and both credential replays; owned resources removed')


if __name__=='__main__': main()
