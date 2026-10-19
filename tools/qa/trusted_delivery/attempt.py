"""Run the actual shipping transfer, including explicitly bounded real transport faults."""
import json
from pathlib import Path
import re
import signal
import sys
from tools.release.delivery.commands import execute
from tools.release.delivery.transfer import Transfer

NAMES={'initial','upgrade','retry','recovery-retry','interrupted','ssh-refused','scp-timeout','immutable','downgrade'}


def inputs(name, plan):
    if (name not in NAMES or not isinstance(plan,dict) or set(plan)!={'source','controller','nonce'}
            or any(not isinstance(plan[k],str) or not re.fullmatch('[a-f0-9]{'+str(n)+'}',plan[k])
                   for k,n in (('source',40),('controller',40),('nonce',32)))):
        raise ValueError('Only exact named QA attempt identities are allowed')
    return {**plan,'incoming':Path('/qa/private/incoming')/name,'temporary':Path('/qa/private/drivers')/name}


def main():
    name=sys.argv[1] if len(sys.argv)==2 else ''
    if name not in NAMES: raise SystemExit('Unknown owned QA attempt')
    values=inputs(name,json.loads((Path('/qa/private')/('attempt-'+name+'.json')).read_text()))
    values['temporary'].mkdir(mode=0o700,parents=True,exist_ok=False)
    def executor(argv, timeout, **kwargs):
        if name=='scp-timeout' and argv[0]=='scp':
            # A real bandwidth-capped SCP process is killed by the shipping
            # subprocess wrapper; this does not synthesize a transport result.
            return execute([argv[0],'-l','8',*argv[1:]],1,**kwargs)
        return execute(argv,timeout,**kwargs)
    value=Transfer(values['source'],values['controller'],values['incoming'],values['temporary'],
                   Path('/qa/private/client'),'operator','127.0.0.2' if name=='ssh-refused' else '127.0.0.1',
                   executor=executor,nonce=values['nonce'])
    def interrupted(signum, frame): raise SystemExit(128+signum)
    signal.signal(signal.SIGTERM,interrupted)
    result=None
    try:
        result=value.run()
    except Exception:
        raise SystemExit('Owned QA attempt failed; sanitized phase receipt retained') from None
    finally:
        (Path('/qa')/('attempt-'+name+'.json')).write_text(json.dumps(
            result if result is not None else value.phases.failure(),sort_keys=True)+'\n')
    print('QA395_ATTEMPT '+name+' PASS')


if __name__=='__main__': main()
