"""Run fast, read-only generators; never interpret unavailable tools as PASS."""
import subprocess
import sys


def check(root, command, timeout=15):
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, timeout=timeout)
        output = result.stdout + result.stderr
        unavailable = result.returncode != 0 and (b'ModuleNotFoundError' in output or b'No module named' in output)
        status = 'PASS' if result.returncode == 0 else 'BLOCKED' if unavailable else 'FAIL'
        return {'status': status, 'command': command,
                'reason': 'Tool or Python dependency unavailable' if unavailable else
                          'Verifier failed; run the command for details.' if result.returncode else ''}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {'status': 'BLOCKED', 'command': command, 'reason': type(error).__name__}


def generated_checks(root):
    return {
        'product_map': check(root, [sys.executable, '-m', 'tools.product_map', 'generate', '--check']),
        'flow_contract': check(root, ['node', 'tools/observability/flow_contract/generate.mjs', '--check']),
    }
