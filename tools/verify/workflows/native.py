"""Validate native signing queue and artifact retention by workflow dependency edges."""
from pathlib import Path
import yaml
from tools.verify.action_pins.policy import normalized
from .delivery import commands
from .selection import require


def check(workflows):
    from tools.ci.artifact_policy.workflows import windows
    windows(workflows['flutter-windows.yaml']['jobs'])
    from tools.ci.windows_gates.workflow import validate as validate_windows
    validate_windows(workflows['flutter-windows.yaml'])
    from tools.ci.flutter_gates.workflow import validate
    validate(workflows['ci-flutter.yaml'])
    from tools.ci.flutter_gates.shadow_workflow import validate as validate_shadow
    validate_shadow(workflows['flutter-ci-shadow.yaml'])
    android = workflows['android-release.yaml']['jobs']
    gates = {name for name, job in android.items() if job.get('uses') == './.github/workflows/ci-flutter.yaml'}
    signing = [job for job in android.values() if 'tools.build.android.run' in commands(job)]
    require(len(gates) == 1 and len(signing) == 1, 'Android requires one native gate before signing')
    needs = signing[0].get('needs', [])
    require(set([needs] if isinstance(needs, str) else needs) == gates, 'Android signing must depend on the native gate')
    for workflow in ('android-release.yaml', 'macos-release.yaml'):
        jobs = [job for job in workflows[workflow]['jobs'].values() if 'steps' in job]
        require(len(jobs) == 1 and jobs[0].get('concurrency') == {
            'group': 'boohtacord-native-signing', 'cancel-in-progress': 'false'}, 'Native signing needs its own non-cancellable queue')
    expected = {'android-release.yaml': 'clients/flutter/build/release-assets/',
                'ci-flutter.yaml': '.out/native/android-debug/',
                'flutter-windows.yaml': 'clients/flutter/build/windows/x64/runner/Release/'}
    for workflow, path in expected.items():
        retained = [step.get('with', {}) for job in workflows[workflow]['jobs'].values()
                    for step in job.get('steps', []) if step.get('uses') == 'actions/upload-artifact@v4']
        require(any(item.get('path') == path and item.get('retention-days') == '30'
                    and item.get('if-no-files-found') == 'error' for item in retained),
                'Native distributions and metadata must be retained together: ' + workflow)


def main():
    root = Path(__file__).resolve().parents[3]
    workflows = {p.name: yaml.load(normalized(p.read_text(encoding='utf-8')), Loader=yaml.BaseLoader)
                 for p in (root / '.github/workflows').glob('*.yaml')}
    check(workflows)
    print('Native gate, signing queue and retained metadata policy: OK')


if __name__ == '__main__': main()
