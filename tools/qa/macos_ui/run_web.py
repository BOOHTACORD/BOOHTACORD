"""Launch the owned Web scenario with interactive stdin and private configuration."""
import argparse
import os
from pathlib import Path
import stat
import subprocess


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work',required=True,type=Path)
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[3]
    output=root/'.out/macos_ui'
    work=args.work.resolve()
    if work.parent != output.resolve() or not work.name.startswith('owned-'):
        raise SystemExit('Expected this runner\'s owned work directory')
    private=work/'browser-private.json'
    if stat.S_IMODE(private.stat().st_mode) != 0o600:
        raise SystemExit('Owner-only fixture configuration required')
    environment=dict(os.environ,QA_INPUT=str(private),QA_ORIGIN='https://localhost:4850',QA_RESULT=str(output/'web-result.json'),QA_CAPTURES=str(output/'web-captures'))
    subprocess.run(['node',str(Path(__file__).with_name('web_scenario.mjs'))],cwd=root,env=environment,check=True)


if __name__ == '__main__':
    main()
