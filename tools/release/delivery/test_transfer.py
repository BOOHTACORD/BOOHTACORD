"""The shared installer never accepts transfer completion as runtime success."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import transfer
from .commands import ExecutionFailed
from .test_readback_contract import fixture, SHA, PRIOR, CONTROLLER, NONCE
from tools.release.install.diagnostics import failure_response, success_response


class SharedTransferTests(unittest.TestCase):
    def fixture(self, root, *, failure=None, forged=False, bad_head=False):
        incoming=root/'incoming'; incoming.mkdir(); temporary=root/'temp'; temporary.mkdir()
        bundle=incoming/(SHA+'.release.tar.gz'); bundle.write_bytes(b'signed-payload')
        (incoming/(bundle.name+'.sha256')).write_text(hashlib.sha256(bundle.read_bytes()).hexdigest()+'  '+bundle.name+'\n')
        calls=[]
        def executor(argv, timeout, **kwargs):
            calls.append((argv, timeout, kwargs))
            if argv[:2] == ['git', 'rev-parse']: return (SHA if bad_head else CONTROLLER).encode()+b'\n'
            if argv[:2] == ['git', 'archive']:
                Path(next(v.removeprefix('--output=') for v in argv if v.startswith('--output='))).write_bytes(b'trusted-driver')
            if argv[0] == 'scp' and failure == 'transfer': raise ExecutionFailed('timeout')
            if argv[0] == 'ssh':
                if len(argv[argv.index('--')+1:]) == 1: return PRIOR.encode()+b'\n'
                if '--' in argv and len(argv[argv.index('--')+1:]) == 6:
                    result = failure_response('deployment') if failure == 'install' else success_response()
                    return json.dumps(result).encode()
                value=fixture(); value['nonce']='0'*32 if forged else NONCE
                return json.dumps(value).encode()
            return b''
        value=transfer.Transfer(SHA, CONTROLLER, incoming, temporary, root, 'operator', '127.0.0.1', executor=executor, nonce=NONCE)
        return value,calls

    def test_current_trusted_controller_installs_an_exact_older_source_with_fresh_readback(self):
        with tempfile.TemporaryDirectory() as tmp:
            value,calls=self.fixture(Path(tmp).resolve()); result=value.run()
        self.assertEqual('PASS', result['status']); self.assertEqual(SHA, result['readback']['source_revision'])
        archive=next(argv for argv,_,_ in calls if argv[:2] == ['git','archive'])
        self.assertIn(CONTROLLER, archive); self.assertNotIn(SHA, archive)
        ssh=[(argv,limit) for argv,limit,_ in calls if argv[0]=='ssh']
        self.assertEqual([45,600,45], [limit for _,limit in ssh])
        self.assertTrue(all('ConnectTimeout=10' in argv and 'StrictHostKeyChecking=yes' in argv for argv,_ in ssh))
        scps=[argv for argv,_,_ in calls if argv[0]=='scp']
        self.assertEqual(2,len(scps)); self.assertTrue(all(NONCE in argv[-1] for argv in scps))

    def test_transfer_timeout_does_not_start_remote_installer_or_readback(self):
        with tempfile.TemporaryDirectory() as tmp:
            value,calls=self.fixture(Path(tmp).resolve(), failure='transfer')
            with self.assertRaises(transfer.PhaseFailed): value.run()
            receipt=value.phases.failure()
        self.assertEqual('transfer_bundle',receipt['phases'][-1]['phase'])
        self.assertEqual('timeout',receipt['phases'][-1]['failure_code'])
        self.assertEqual(1,len([a for a,_,_ in calls if a[0]=='ssh']))

    def test_nonzero_installer_or_old_readback_never_reports_pass(self):
        for failure,forged in [('install',False),(None,True)]:
            with tempfile.TemporaryDirectory() as tmp:
                value,calls=self.fixture(Path(tmp).resolve(), failure=failure, forged=forged)
                with self.assertRaises(transfer.PhaseFailed): value.run()
                receipt=value.phases.failure()
                self.assertEqual('FAIL',receipt['status'])
                if failure == 'install':
                    self.assertEqual('installer_deployment',receipt['phases'][-1]['failure_code'])
                    self.assertEqual(2,len([argv for argv,_,_ in calls if argv[0]=='ssh']))

    def test_bad_controller_or_bundle_checksum_cannot_reach_any_ssh(self):
        for mutation in ('head','bundle'):
            with tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp).resolve(); value,calls=self.fixture(root,bad_head=mutation=='head')
                if mutation=='bundle': (root/'incoming'/(SHA+'.release.tar.gz')).write_bytes(b'tampered')
                with self.assertRaises((ValueError,ExecutionFailed)): value.run()
                self.assertFalse(any(a[0] in ('ssh','scp') for a,_,_ in calls))

    def test_remote_arguments_cannot_be_shell_syntax_or_a_foreign_stage(self):
        for user,address,nonce in [('op;id','127.0.0.1',NONCE),('operator','host;id',NONCE),('operator','127.0.0.1','../bad')]:
            with tempfile.TemporaryDirectory() as tmp,self.assertRaises(ValueError):
                root=Path(tmp).resolve()
                transfer.Transfer(SHA,CONTROLLER,root,root,root,user,address,nonce=nonce)
