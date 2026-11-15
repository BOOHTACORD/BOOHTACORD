"""Fast inventory only; manual and native checks are explicitly unresolved."""
import argparse
import json
import subprocess
from pathlib import Path

from tools.ci.preflight.inventory import inventory
from tools.ci.preflight.dependencies import dependency_review
from tools.ci.preflight.client_registry import check as client_registry_check
from tools.ci.preflight.generated import generated_checks
from tools.ci.preflight.fingerprint import snapshot
from tools.ci.preflight.obligations import obligations, suspicious
from tools.ci.preflight.review import decision
from tools.ci.preflight.related_checks import checks as related_checks
from tools.ci.actual_acceptance.plan import select as actual_selection
from tools.ci.select_changes.selection import classify


def report(root, base):
    try:
        changes = inventory(root, base)
        selection = classify(changes['paths'])
        unknown_paths = [path for path in changes['paths'] if classify([path])['uncertain']]
        actual = actual_selection(changes['paths'])
        checks = [subprocess.run(['git', 'diff', '--check', *args, '--'], cwd=root,
                                 capture_output=True).returncode
                  for args in ([changes['merge_base'], 'HEAD'], ['--cached'], [])]
        for path in changes['untracked']:
            code = subprocess.run(['git', 'diff', '--no-index', '--check', '--', '/dev/null', path],
                                  cwd=root, capture_output=True).returncode
            checks.append(0 if code in (0, 1) else code)
        unwanted = [p for p in changes['paths'] if suspicious(p)]
        dependency_note = dependency_review(root, changes)
        fingerprint = snapshot(root, changes)
        generated = generated_checks(root)
        client_registry = client_registry_check(root, changes)
        related = related_checks(root, changes['paths'])
        latest = inventory(root, base)
        changed_during_check = latest != changes or snapshot(root, latest) != fingerprint
        return {'inventory': changes, 'fingerprint': fingerprint,
                'selection': selection, 'unknown_paths': unknown_paths, 'actual_acceptance': actual,
                'diff_check': 'PASS' if not any(checks) else 'FAIL',
                'unexpected_or_sensitive_paths': unwanted,
                'dependency_review': dependency_note,
                'generated_checks': generated, 'client_registry_check': client_registry,
                'related_checks': related,
                'scope_changed_during_check': changed_during_check,
                'obligations': obligations(changes['paths']),
                'decision': 'COMMIT_BLOCKED',
                'reason': 'Manual applicability review and applicable checks have not been attested by this tool.'}
    except (OSError, UnicodeError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        return {'decision': 'COMMIT_BLOCKED', 'reason': f'Cannot determine scope: {type(error).__name__}; verify base ref, Git and file access.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', required=True, help='target branch or commit')
    parser.add_argument('--json', action='store_true', help='emit machine-readable JSON')
    parser.add_argument('--review', help='JSON file containing explicit manual attestations')
    args = parser.parse_args()
    result = report(Path.cwd(), args.base)
    if args.review and 'fingerprint' in result:
        try:
            review = json.loads(Path(args.review).read_text(encoding='utf-8'))
            result['decision'] = decision(result, review)
            if result['decision'] == 'COMMIT_ALLOWED':
                result['manual_attestation'] = review['checks']
                result['pending_hosted_ci'] = sorted(name for name, item in review['checks'].items()
                                                     if isinstance(item, dict) and item.get('status') == 'BLOCKED')
                for name, item in result['obligations'].items():
                    item['status'] = review['checks'][name]['status']
                    item['attested'] = True
            result['reason'] = ('Manual attestation accepted; commands are not independently executed by this tool.'
                                if result['decision'] == 'COMMIT_ALLOWED' else 'Attestation is incomplete, stale or blocked.')
        except (OSError, ValueError, TypeError):
            result['reason'] = 'Cannot read valid manual attestation.'
    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=True))
    else:
        print(f"Decision: {result['decision']} - {result['reason']}")
        if 'inventory' in result:
            inventory_result = result['inventory']
            print(f"Base: {inventory_result['base']} ({inventory_result['base_commit']})  merge-base: {inventory_result['merge_base']}")
            print(f"Review fingerprint: {result['fingerprint']}")
            for key in ('committed', 'staged', 'unstaged', 'untracked'):
                print(f"{key}: {json.dumps(inventory_result[key], ensure_ascii=True)}")
            print(f"Selected gates: {', '.join(result['selection']['gates'])}; uncertain={result['selection']['uncertain']}")
            print(f"Unmapped paths: {json.dumps(result['unknown_paths'], ensure_ascii=True)}")
            print(f"Actual acceptance: {json.dumps(result['actual_acceptance'])}")
            if result.get('pending_hosted_ci'):
                print(f"Required hosted CI remains BLOCKED: {json.dumps(result['pending_hosted_ci'])}")
            print(f"git diff --check: {result['diff_check']}")
            print(f"Unexpected/sensitive: {json.dumps(result['unexpected_or_sensitive_paths'], ensure_ascii=True)}")
            print(result['dependency_review'])
            for name, item in result['generated_checks'].items():
                print(f"{name}: {item['status']} - {json.dumps(item['command'])} {item['reason']}")
            print(f"Client registry: {json.dumps(result['client_registry_check'], ensure_ascii=True)}")
            for name, item in result['related_checks'].items():
                print(f"{name}: {item['status']} - {json.dumps(item['command'])} {item['reason']}")
            for name, item in result['obligations'].items():
                print(f"{name}: {item['status']} - {item['action']}")
        print('Complete the review in docs/development/codex-ci-readiness.md.')
    return 1 if result['decision'] == 'COMMIT_BLOCKED' else 0


if __name__ == '__main__':
    raise SystemExit(main())
