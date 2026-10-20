"""One isolated actual SSH installation/retry/fault/rollback rehearsal."""
import argparse
from datetime import datetime,timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from .daemon import Daemon
from .evidence import validate
from .runtime_inputs import ordered
from tools.qa.local_features.process import stop_group
from tools.qa.compatible_rollback.builder_identity import builder_hashes


def harness_hashes(root):
    paths = [p for directory in ('trusted_delivery','compatible_rollback')
             for p in (root/'tools/qa'/directory).iterdir()
             if p.suffix in ('.py','.mjs','.json') or p.name=='Dockerfile']
    paths.append(root/'tools/qa/client_lifecycle/request.mjs')
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}


def metrics(work, destination, proof):
    for role in ('current','previous'):
        source = proof[role]['head']
        path = work/'releases'/(source+'.build.json')
        if path.is_file() and not path.is_symlink() and path.stat().st_size<=100_000:
            value = json.loads(path.read_bytes())
            if value.get('source_revision')!=source:
                raise ValueError('Actual builder metrics source differs')
            shutil.copyfile(path,destination/('build-'+source+'.json'))


def public_results(work, destination):
    for name,target in (('delivery-runtime.json','delivery.json'),('negative-runtime.json','negatives.json')):
        path=work/name
        if path.is_file() and not path.is_symlink() and path.stat().st_size<=1_000_000:
            # These are generated solely by the source-bound public report
            # writers. Keep partial FAIL results as well as accepted receipts.
            shutil.copyfile(path,destination/target)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--ci-proof',type=Path,required=True)
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[3]
    subprocess.run(['git','diff','--exit-code','HEAD','--'],cwd=root,check=True,stdout=subprocess.DEVNULL)
    controller=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
    original=json.loads(args.ci_proof.read_text())
    proof=ordered(original,lambda older,newer: subprocess.run(
        ['git','merge-base','--is-ancestor',older,newer],cwd=root,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0)
    destination=root/'.out/issue395/runtime'
    destination.mkdir(parents=True,exist_ok=False)
    report=dict(schema_version=1,kind='trusted-delivery-runtime',status='RUNNING',source_base=controller,
        ci_proof=original,runtime_role_mapping={'baseline':'previous','next':'current'},
        scope='Owned isolated Linux amd64 daemon and QA-only trust; no production access',
        production='NOT_RUN',harness_sha256=harness_hashes(root),builder_sha256=builder_hashes(root))
    began=datetime.now(timezone.utc)
    report['started_at']=began.isoformat()
    def save(): (destination/'run.json').write_text(json.dumps(report,indent=2)+'\n')
    save()
    try:
        with tempfile.TemporaryDirectory(prefix='qa395-',dir=root/'.out') as temporary:
            work=Path(temporary)
            for role,source in [('current',proof['current']['head']),('previous',proof['previous']['head']),('controller',controller)]:
                path=work/role
                subprocess.run(['git','clone','--shared','--no-checkout',str(root),str(path)],check=True,capture_output=True)
                subprocess.run(['git','checkout','--detach',source],cwd=path,check=True,capture_output=True)
            (work/'ci-proof.json').write_text(json.dumps(proof))
            stack=Daemon(root,work); node=None
            def execute(phase,log,timeout):
                stack.execute('env','PYTHONPATH=/qa-builder:/qa-tools','python3','-m',
                    'tools.qa.trusted_delivery.controller',phase,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
            try:
                with (destination/'prepare-private.log').open('wb') as log:
                    stack.start()
                    print('QA395_PHASE genuine signed cold/warm bundles and owned loopback SSH',flush=True)
                    execute('prepare',log,3600)
                stack.reclaim()
                metrics(work,destination,proof)
                report['environment']=json.loads((work/'environment.json').read_text())
                report['ssh_public']=json.loads((work/'ssh-public.json').read_text())
                with (destination/'browser-private.log').open('wb') as log:
                    node=subprocess.Popen(['node',str(root/'tools/qa/trusted_delivery/scenario.mjs')],cwd=root,
                        env=dict(os.environ,QA395_WORK=str(work),QA395_OUTPUT=str(destination)),
                        stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
                    deadline=time.monotonic()+90
                    while not (work/'browser-ready.json').exists():
                        if node.poll() is not None or (work/'browser-failure.json').exists():
                            raise RuntimeError('Actual browser dataset preparation failed')
                        if time.monotonic()>deadline:raise TimeoutError('Actual browser preparation exceeded its bound')
                        time.sleep(.2)
                    print('QA395_PHASE shipping SSH install/retry/interruption, compatible rollback and actual negatives',flush=True)
                    with (destination/'controller-private.log').open('wb') as controller_log:
                        execute('exercise',controller_log,1800)
                    if node.wait(timeout=20):raise RuntimeError('Actual browser observers failed')
                stack.reclaim()
                receipt=json.loads((work/'delivery-runtime.json').read_text())
                validate(receipt,window=(began,datetime.now(timezone.utc)))
                if harness_hashes(root)!=report['harness_sha256'] or builder_hashes(root)!=report['builder_sha256']:
                    raise RuntimeError('Accepted controller source changed during execution')
                shutil.copyfile(work/'delivery-runtime.json',destination/'delivery.json')
                report['captures']=[dict(file=p.name,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
                                    for p in sorted(destination.glob('*.png'))]
                report['status']='PASS'
            finally:
                if node is not None and node.poll() is None:stop_group(node)
                try:
                    metrics(work,destination,proof)
                    public_results(work,destination)
                finally:
                    try:stack.close()
                    finally:report['owned_resources_removed']=not stack.resources
    except BaseException as error:
        report.update(status='FAIL',error_type=type(error).__name__)
        from tools.qa.compatible_rollback.diagnostics import diagnose,public_guards
        messages=public_guards(root)
        report['diagnostics']={name:diagnose(path.read_text(errors='replace'),messages)
            for name in ('prepare-private','controller-private')
            if (path:=destination/(name+'.log')).is_file()}
        raise
    finally:
        report['finished_at']=datetime.now(timezone.utc).isoformat()
        save()


if __name__=='__main__':main()
