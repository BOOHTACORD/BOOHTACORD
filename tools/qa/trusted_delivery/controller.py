"""Trusted QA phases inside the owned Unix-only Linux daemon."""
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    work = Path('/qa')
    if sys.argv[1:] == ['prepare']:
        for role in ('current','previous','controller'):
            subprocess.run(['git','config','--global','--add','safe.directory',str(work/role)], check=True)
        from .build import build
        build(work)
        from setup import prepare
        prepare(work)
        from .ssh_fixture import start
        (work/'ssh-public.json').write_text(json.dumps(start(work)))
    elif sys.argv[1:] == ['exercise']:
        os.environ['CURL_CA_BUNDLE'] = str(work/'ca.crt')
        from .positive import run
        from .faults import run as negatives
        from .evidence import validate
        report = run(work)
        try:
            report['negatives'] = negatives(work, report)
            validate(report)
        except BaseException:
            report['status'] = 'FAIL'
            raise
        finally:
            (work/'delivery-runtime.json').write_text(json.dumps(report, indent=2)+'\n')
    else:
        raise ValueError('An explicit owned QA phase is required')


if __name__ == '__main__': main()
