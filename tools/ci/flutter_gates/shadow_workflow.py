"""Finite read-only native control derived from the immutable original workflow."""
from tools.ci.runner_pool.routing import GITHUB_LINUX
from tools.ci.toolchains.auxiliary import policy
import copy
import hashlib
import json
import yaml
from tools.ci.native.process import ROOT
from tools.verify.action_pins.policy import normalized
from .legacy import reference, frozen

UPLOAD = 'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02'
DOWNLOAD = 'actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093'
IDENTITY = '${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'


def read_baseline_source():
    return frozen('.github/workflows/ci-flutter.yaml').decode()


def definition():
    original = read_baseline_source()
    if hashlib.sha256(original.encode()).hexdigest() != reference()['files']['.github/workflows/ci-flutter.yaml']:
        raise ValueError('Native control template differs from its original workflow')
    old = yaml.load(original, Loader=yaml.BaseLoader)['jobs']['flutter']
    legacy = copy.deepcopy(old)
    legacy['runs-on'] = GITHUB_LINUX
    legacy.update({'name': 'legacy-${{ matrix.sample }}', 'timeout-minutes': 40,
                   'strategy': {'fail-fast': False, 'max-parallel': 1, 'matrix': {'sample': [1, 2, 3]}},
                   'env': {'FLUTTER_EVIDENCE_NAMESPACE': 'shadow-old-${{ matrix.sample }}'}})
    legacy['steps'][0]['with']['fetch-depth'] = 0
    commands = {'python3 -m tools.ci.native.flutter': 'python3 -m tools.ci.flutter_gates.legacy dart',
                'bash tools/verify/android_kotlin/verify_android_kotlin_modes.sh': 'python3 -m tools.ci.flutter_gates.legacy kotlin',
                'python3 -m tools.build.android.run --debug': 'python3 -m tools.ci.flutter_gates.legacy apk'}
    for step in legacy['steps']:
        if step.get('uses', '').startswith('actions/setup-java@'):
            # Both cohorts use the resolvable official pin for the same runtime;
            # the original source bytes and phase inventory stay frozen.
            step['with']['java-version'] = policy(ROOT)['java']
        if step.get('run') in commands:
            step['run'] = commands[step['run']]
        if step.get('uses') == UPLOAD:
            name = step['with']['name'].removesuffix('-${{ github.sha }}')
            step['with']['name'] = name + '-${{ env.FLUTTER_EVIDENCE_NAMESPACE }}-' + IDENTITY
    legacy['steps'].extend([
        {'name': 'Verify complete original phases and measured artifact evidence',
         'run': 'python3 -m tools.ci.flutter_gates.legacy finish'},
        {'name': 'Retain complete original source-bound execution', 'if': 'always()', 'uses': UPLOAD,
         'with': {'name': 'flutter-legacy-${{ env.FLUTTER_EVIDENCE_NAMESPACE }}-' + IDENTITY,
                  'path': '.out/ci/flutter-legacy.json', 'if-no-files-found': 'error', 'retention-days': 30}}])
    compare = {'if': 'always()', 'needs': ['legacy', 'profiles'], 'runs-on': GITHUB_LINUX, 'timeout-minutes': 5,
               'env': {'FLUTTER_EVIDENCE_NAMESPACE': 'shadow-compare'},
               'steps': [copy.deepcopy(old['steps'][0]), copy.deepcopy(old['steps'][1]), copy.deepcopy(old['steps'][2])]}
    for prefix, pattern in [('legacy', 'flutter-legacy-shadow-old-*-'), ('profile', 'flutter-part-shadow-new-*-')]:
        compare['steps'].append({'name': 'Download only current ' + prefix + ' execution parts', 'uses': DOWNLOAD,
                                'with': {'pattern': pattern + IDENTITY + ('-*' if prefix == 'profile' else ''),
                                         'path': '.out/ci/flutter-shadow-inputs', 'merge-multiple': False}})
    compare['steps'].extend([
        {'name': 'Compare complete same-source controls with actual job metadata', 'if': 'always()',
         'env': {'FLUTTER_SHADOW_NEEDS': '${{ toJSON(needs) }}', 'GITHUB_TOKEN': '${{ github.token }}'},
         'run': 'python3 -m tools.ci.flutter_gates.measure'},
        {'name': 'Retain bounded comparison including FAIL or NO_GAIN', 'if': 'always()', 'uses': UPLOAD,
         'with': {'name': 'flutter-ci-shadow-' + IDENTITY, 'path': '.out/ci/flutter-shadow.json',
                  'if-no-files-found': 'error', 'retention-days': 30}}])
    return {'name': 'Flutter CI shadow comparison', 'on': {'workflow_dispatch': {}},
            'permissions': {'contents': 'read', 'actions': 'read'},
            'concurrency': {'group': 'flutter-shadow-${{ github.ref }}', 'cancel-in-progress': True},
            'jobs': {'legacy': legacy, 'profiles': {
                'name': 'profiles-${{ matrix.sample }}',
                'strategy': {'fail-fast': False, 'max-parallel': 1, 'matrix': {'sample': [1, 2, 3]}},
                'uses': './.github/workflows/ci-flutter.yaml',
                'with': {'evidence_namespace': 'shadow-new-${{ matrix.sample }}'}}, 'compare': compare}}


def validate(document):
    expected = yaml.load(normalized(yaml.safe_dump(definition(), sort_keys=False)), Loader=yaml.BaseLoader)
    if document != expected:
        raise ValueError('Native shadow workflow must preserve the complete read-only original control and isolated finite samples')
