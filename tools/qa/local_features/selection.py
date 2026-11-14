"""Select only registered native scenarios and bound every stage."""
import re
import os
import shutil
import sys

from .native import native_target


def host_command(command, *, system=None, find=None, python=None):
    if (system or os.name) != 'nt': return command
    executable = command[0]
    if executable == 'python3': executable = python or sys.executable
    elif executable in {'npm', 'flutter'}: executable = (find or shutil.which)(executable) or executable
    return [executable, *command[1:]]


def native_targets(catalog, features):
    default = 'integration_test/local_qa_test.dart'
    extra = {target for feature in features for target in catalog[feature].get('native_targets', [])}
    for target in extra:
        native_target(target)
    return [default, *sorted(extra - {default})]


def stage_timeout(name):
    return 3600 if name == 'flutter-unit' else 1800


def flutter_unit_result(returncode, output):
    if returncode != 0:
        return 'FAIL', None
    matches = re.findall(r'(?:^|[\r\n])\s*\d+:\d+\s+\+\d+(?:\s+~(\d+))?: All tests passed!', output)
    if not matches:
        return 'BLOCKED', None
    skipped = int(matches[-1] or 0)
    return ('BLOCKED' if skipped else 'PASS'), skipped


def web_test_result(name, returncode, output):
    if returncode != 0:
        return 'FAIL', None
    output = re.sub(r'\x1b\[[0-9;]*m', '', output)
    if name == 'web-unit':
        matches = re.findall(r'(?m)^\s*Tests\s+(.+)$', output)
        if not matches:
            return 'BLOCKED', None
        row = matches[-1]
        skipped = re.search(r'\b(\d+)\s+skipped\b', row)
        if skipped and int(skipped.group(1)):
            return 'BLOCKED', int(skipped.group(1))
        return ('PASS', 0) if re.search(r'\b\d+\s+passed\b', row) else ('BLOCKED', None)
    skipped = re.findall(r'(?m)^\s*(\d+)\s+skipped\s*$', output)
    if skipped and sum(map(int, skipped)):
        return 'BLOCKED', sum(map(int, skipped))
    passed = re.findall(r'(?m)^\s*\d+\s+passed(?:\s+\([^\r\n]*\))?\s*$', output)
    return ('PASS', 0) if passed else ('BLOCKED', None)


def records_test_summary(name):
    return (name in {'flutter-unit', 'flutter-component-captures', 'web-unit'} or
            (name.startswith('web-') and name != 'web-build' and not name.startswith('web-real-stack-')))


def flutter_stage_result(name, returncode, output):
    if name in {'flutter-unit', 'flutter-component-captures'}:
        return flutter_unit_result(returncode, output)
    if records_test_summary(name):
        return web_test_result(name, returncode, output)
    return ('PASS' if returncode == 0 else 'FAIL'), None
