"""Guard native coverage, isolated jobs, mandatory uploads and stable aggregation."""
CONTEXT = '${{ inputs.evidence_namespace }}-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'


def require(condition):
    if not condition:
        raise ValueError('Flutter CI requires isolated full profiles and complete current artifact evidence')


def command(job, value):
    steps = [s for s in job.get('steps', []) if s.get('run') == value]
    require(len(steps) == 1 and not steps[0].get('if') and not steps[0].get('continue-on-error'))
    return steps[0]


def upload(job, path, name, always=False):
    steps = [s for s in job.get('steps', []) if s.get('uses') == 'actions/upload-artifact@v4'
             and s.get('with', {}).get('path') == path]
    require(len(steps) == 1)
    step = steps[0]
    require(step.get('with') == {'name': name, 'path': path, 'if-no-files-found': 'error', 'retention-days': '30'}
            and not step.get('continue-on-error') and step.get('if') == ('always()' if always else None))


def validate(document):
    require(document.get('permissions') == {'contents': 'read'})
    require(document.get('on') == {'workflow_call': {'inputs': {
        'evidence_namespace': {'type': 'string', 'default': 'flutter'}}}})
    jobs = document.get('jobs', {})
    require(set(jobs) == {'dart', 'android', 'flutter'})
    for profile, timeout in (('dart', '20'), ('android', '30')):
        job = jobs[profile]
        require(job.get('runs-on') == 'ubuntu-24.04' and job.get('timeout-minutes') == timeout
                and not any(job.get(k) for k in ('if', 'needs', 'continue-on-error', 'environment', 'secrets')))
        sdk = [s for s in job.get('steps', []) if s.get('uses') == './.github/actions/flutter-setup']
        require(len(sdk) == 1 and sdk[0].get('with') == {'channel': 'stable', 'flutter-version': '3.47.7', 'cache': 'true'}
                and not sdk[0].get('if'))
        step = command(job, 'python3 -m tools.ci.flutter_gates.run ' + profile)
        require(step.get('env') == {'FLUTTER_EVIDENCE_NAMESPACE': '${{ inputs.evidence_namespace }}'})
        upload(job, '.out/ci/flutter-parts/' + profile + '.json', 'flutter-part-' + CONTEXT + '-' + profile, True)
    upload(jobs['dart'], '.out/visual/flutter/R14-navigation-top.png', 'flutter-navigation-actual-' + CONTEXT)
    upload(jobs['dart'], '.out/visual/flutter/**', 'uiux-flutter-visual-review-' + CONTEXT, True)
    upload(jobs['android'], '.out/native/android-debug/', 'boohtacord-android-debug-apk-' + CONTEXT)
    aggregate = jobs['flutter']
    require(aggregate.get('if') == 'always()' and set(aggregate.get('needs', [])) == {'dart', 'android'}
            and aggregate.get('runs-on') == 'ubuntu-24.04' and aggregate.get('timeout-minutes') == '5'
            and not aggregate.get('continue-on-error'))
    downloads = [s for s in aggregate.get('steps', []) if s.get('uses') == 'actions/download-artifact@v4']
    require(len(downloads) == 1 and not downloads[0].get('if') and downloads[0].get('with') == {
        'pattern': 'flutter-part-' + CONTEXT + '-*', 'path': '.out/ci/flutter-parts', 'merge-multiple': 'true'})
    step = command(aggregate, 'python3 -m tools.ci.flutter_gates.aggregate')
    require(step.get('env') == {'FLUTTER_NEEDS': '${{ toJSON(needs) }}',
                              'FLUTTER_EVIDENCE_NAMESPACE': '${{ inputs.evidence_namespace }}'})
