"""Run a real gate and retain its result for the exact checked-out source SHA."""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from tools.ci.native.process import ROOT, output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("gate", choices=("backend", "web", "contracts"))
    parser.add_argument('--parts', type=Path, help='Complete source-bound Web or backend profile reports')
    args = parser.parse_args()
    if args.parts and args.gate not in ('web', 'backend'):
        raise ValueError('Only Web and backend gates accept reviewed parallel profile results')
    revision = output("git", "rev-parse", "HEAD")
    if os.environ.get("GITHUB_SHA", revision) != revision:
        raise RuntimeError("CI source SHA differs from checkout")
    subprocess.run(["git", "diff", "--exit-code", "HEAD", "--"], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    destination = ROOT / ".out/checks"
    destination.mkdir(parents=True, exist_ok=True)
    receipt = {'source_revision': revision, 'gate': args.gate, 'status': 'FAIL'}
    path = destination / (args.gate + '.json')
    path.write_text(json.dumps(receipt, sort_keys=True) + '\n', encoding='utf-8')
    if args.parts:
        if args.gate == 'web':
            from tools.ci.web_suites.fan_in import read_reports, validate_results
        else:
            from tools.ci.backend_gates.results import read_reports, validate as validate_results
        summary = validate_results(revision, json.loads(os.environ[args.gate.upper() + '_NEEDS']), read_reports(args.parts))
        result_code = 0
        report = ROOT / ('.out/ci/' + args.gate + '-fan-in.json')
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(summary, sort_keys=True) + '\n', encoding='utf-8')
    else:
        module = 'tools.ci.backend_gates.run' if args.gate == 'backend' else 'tools.ci.native.' + args.gate
        result_code = subprocess.run([sys.executable, '-m', module], cwd=ROOT).returncode
    receipt['status'] = 'PASS' if result_code == 0 else 'FAIL'
    path.write_text(json.dumps(receipt, sort_keys=True) + '\n', encoding='utf-8')
    raise SystemExit(result_code)


if __name__ == "__main__":
    main()
