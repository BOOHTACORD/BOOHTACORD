"""Manual operator audit receipt; raw host output, keys and observations never become artifacts."""
import argparse
import json
import os
from pathlib import Path
import signal
import tempfile
import time
from tools.ci.native.process import ROOT,output
from . import approval
from .operations import perform
from .policy import require,request,OPERATIONS
from .transport import SSH


def execute(operation):
    destination=ROOT/'.out/operator'/operation;destination.mkdir(parents=True,exist_ok=False)
    receipt=dict(schema_version=1,operation=operation,status='BLOCKED',phase='validate',host_observed=False,
                 production_mutation=False,private_runner_material_removed=False,reviewer_ids=[])
    started=time.monotonic();old_signal=None;failed=False;private=None
    try:
        plan=request(operation,os.environ);receipt.update({k:v for k,v in plan.items() if k!='timeout'})
        require(output('git','rev-parse','HEAD')==plan['source_revision'])
        if plan['dry_run']:
            receipt.update(status='NOT_RUN',phase='dry-run',reason='NoHostAccess');return
        require(os.environ.get('GITHUB_ACTIONS')=='true' and os.environ.get('RUNNER_ENVIRONMENT')=='github-hosted')
        receipt['phase']='approval';receipt['reviewer_ids']=approval.verify(plan)
        def interrupted(*_):raise InterruptedError('Operator execution interrupted')
        old_signal=signal.signal(signal.SIGTERM,interrupted)
        with tempfile.TemporaryDirectory(prefix='operator-',dir=os.environ['RUNNER_TEMP']) as private:
            Path(private).chmod(0o700);ssh=SSH(private,os.environ)
            receipt.update(phase='host-operation',status='FAIL',mutation_attempted=plan['risk']=='mutation')
            perform(plan,ssh,private,audit=receipt)
            receipt.update(status='PASS',phase='complete',host_observed=True,production_mutation=plan['risk']=='mutation')
    except BaseException as error:
        failed=True;receipt['failure_type']=type(error).__name__
        # Once a mutation starts, failure cannot assert restoration. The host's
        # guarded rollback and shared installation lock remain authoritative.
        if receipt.get('risk')=='mutation' and receipt['phase']=='host-operation':
            receipt.update(restoration='NOT_VERIFIED',production_mutation='NOT_VERIFIED',host_cleanup='NOT_VERIFIED')
    finally:
        if old_signal is not None:signal.signal(signal.SIGTERM,old_signal)
        removed=private is None or not Path(private).exists()
        if not removed:failed=True;receipt.update(status='FAIL',failure_type='PrivateCleanupFailed')
        receipt.update(seconds=round(time.monotonic()-started,3),private_runner_material_removed=removed)
        (destination/'receipt.json').write_text(json.dumps(receipt,sort_keys=True)+'\n')
        print('Operator '+operation+': '+receipt['status']+'; private host observations omitted')
    if failed:raise SystemExit(1)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('operation',choices=OPERATIONS);args=parser.parse_args();execute(args.operation)


if __name__=='__main__':main()
