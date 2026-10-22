"""Owned real support DM acceptance; never connects to a deployment or GitHub."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from tools.qa.local_features.stack import Stack
from tools.qa.client_lifecycle.services import output, run
ROOT=Path(__file__).resolve().parents[3]

def main():
    stamp=time.strftime('%Y%m%d-%H%M%S')
    folder=ROOT/'.out/support-contact'/stamp
    folder.mkdir(parents=True,exist_ok=False)
    report={'status':'FAIL','mocks':False,'physical_acceptance':'NOT_RUN','owned_resources_removed':False}
    try:
        run('npm','run','build',cwd=ROOT/'clients/web',env=dict(os.environ,VITE_PUBLIC_ORIGIN='https://localhost:4810'),stdout=subprocess.DEVNULL)
        with tempfile.TemporaryDirectory(prefix='support516-',dir=ROOT/'.out') as temporary:
            work=Path(temporary);stack=Stack(ROOT,work)
            try:
                stack.start()
                # Synthetic ordinary accounts share the synthetic fixture hash;
                # neither the hash nor any credential is read into an artifact.
                sql="""INSERT INTO users(id,login,display_name,password_hash,role)
                SELECT gen_random_uuid(),name,name,password_hash,'MEMBER'
                FROM users CROSS JOIN (VALUES ('qa_support_a'),('qa_support_b'),('qa_support_s')) AS fixture(name)
                WHERE login='qa_admin';"""
                run('docker','exec',stack.owner+'-db','psql','-U','qa','-d','qa','-v','ON_ERROR_STOP=1','-c',sql,stdout=subprocess.DEVNULL)
                private=work/'input.json';private.write_text(json.dumps({'password':stack.password,'directory':str(folder)}));private.chmod(0o600)
                env=dict(os.environ,QA_ORIGIN='https://localhost:4810',QA_INPUT=str(private),QA_DB_OWNER=stack.owner)
                run('node',str(ROOT/'tools/qa/support_contact/scenario.mjs'),env=env,timeout=300)
                report.update(json.loads((folder/'browser.json').read_text()))
                report['source_revision']=output('git','-C',str(ROOT),'rev-parse','HEAD')
                report['working_tree_dirty']=bool(output('git','-C',str(ROOT),'status','--porcelain'))
                digest=hashlib.sha256(subprocess.check_output(['git','diff','HEAD','--binary'],cwd=ROOT))
                for name in sorted(subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=ROOT,text=True).splitlines()):
                    digest.update(name.encode());digest.update((ROOT/name).read_bytes())
                report['working_changes_sha256']=digest.hexdigest()
            finally:
                stack.close()
                report['owned_resources_removed']=True
            report['status']='PASS'
    finally:
        (folder/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print('Support contact acceptance: '+report['status']+'; '+str(folder),flush=True)
if __name__=='__main__':main()
