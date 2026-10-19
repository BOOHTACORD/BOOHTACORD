"""Enforce one master server producer and independent read-only native quality."""
from tools.ci.runner_pool.routing import META
from tools.ci.toolchains.auxiliary import ROOT, python_input

MASTER = "github.repository == 'Egkurilov/BOOHTACORD' && github.ref == 'refs/heads/master'"
PR_SCOPE = "github.event_name != 'workflow_dispatch' || github.ref != 'refs/heads/master'"
EXECUTION = '${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'


def require(value):
    if not value:
        raise ValueError('Master quality ownership, source, attempt or mandatory dependency differs')


def selector(job):
    require(job.get('if') == MASTER and job.get('runs-on') == META)
    require(not job.get('environment') and not job.get('secrets') and not job.get('continue-on-error'))
    for key in ('contracts', 'map_version', 'map_sha256', 'uncertain', 'server_release_impact', 'flutter', 'windows'):
        require(job.get('outputs', {}).get(key) == '${{ steps.select.outputs.' + key + ' }}')
    steps = job.get('steps', [])
    commands = [s for s in steps if s.get('run') == 'python3 -m tools.ci.select_changes.run']
    require(len(commands) == 1 and commands[0].get('id') == 'select' and not commands[0].get('if'))
    require(any(s.get('uses') == 'actions/checkout@v4' and s.get('with') == {
        'persist-credentials': 'false', 'fetch-depth': '0'} for s in steps))


def quality(job, scope, roles):
    require(job.get('if') == 'always()' and set(job.get('needs', [])) == set(roles)
            and job.get('runs-on') == META and job.get('timeout-minutes') == '5'
            and not any(key in job for key in ('environment', 'secrets', 'continue-on-error', 'env')))
    steps = job.get('steps', [])
    require(len(steps) == 7 and all(not s.get('continue-on-error') for s in steps))
    require(steps[0] == {'uses': 'actions/checkout@v4', 'with': {'persist-credentials': 'false'}})
    require(steps[1] == {'uses': 'actions/setup-python@v5', 'with': {'python-version': python_input(ROOT)}})
    require(steps[2].get('run') == 'python -m tools.ci.toolchains.runtime python' and not steps[2].get('if'))
    require(steps[3].get('run') == f'python3 -m tools.ci.master_quality.run {scope}'
            and steps[3].get('env') == {'MASTER_NEEDS': '${{ toJSON(needs) }}'} and not steps[3].get('if'))
    require(steps[4].get('uses') == 'actions/upload-artifact@v4' and steps[4].get('if') == 'always()'
            and steps[4].get('with') == {'name': f'quality-master-{scope}-' + EXECUTION,
                                       'path': f'.out/ci/master-{scope}.json',
                                       'if-no-files-found': 'error', 'retention-days': '30'})
    require(steps[5].get('run') == 'python -m tools.ci.observability.summary --scope ' + scope
            and steps[5].get('if') == 'always()'
            and steps[5].get('env') == {'GITHUB_TOKEN':'${{ github.token }}','TRIAGE_NEEDS':'${{ toJSON(needs) }}','CI_GATE_OUTCOME':'${{ job.status }}'})
    require(steps[6].get('uses') == 'actions/upload-artifact@v4' and steps[6].get('if') == 'always()'
            and steps[6].get('with') == {'name':'triage-'+scope+'-'+EXECUTION,'path':'.out/ci/triage/'+scope+'.json',
                'if-no-files-found':'error','retention-days':'30'})
    require(job.get('permissions') == {'contents':'read','actions':'read'})


def validate(workflows):
    try:
        ci = workflows['ci.yaml']
        require(set(ci['on']) == {'pull_request', 'merge_group', 'workflow_dispatch'})
        require(ci['jobs']['changes'].get('if') == ci['jobs']['contracts'].get('if') == PR_SCOPE)
        build, native = workflows['build-server.yaml'], workflows['native-master.yaml']
        for document, prefix in ((build, 'server-build'), (native, 'native-master')):
            require(document['on'] == {'push': {'branches': ['master']}, 'workflow_dispatch': ''})
            require(document['permissions'] == {'contents': 'read'}
                    and document.get('concurrency') == {
                        'group': prefix + '-${{ github.ref }}-${{ github.sha }}',
                        'cancel-in-progress': 'true'})
            selector(document['jobs']['changes'])
        require(set(build['jobs']) == {'changes', 'contracts', 'backend', 'web', 'server-quality', 'bundle'})
        require(set(native['jobs']) == {'changes', 'flutter', 'windows', 'native-required'})
        quality(build['jobs']['server-quality'], 'server', ('changes', 'contracts', 'backend', 'web'))
        quality(native['jobs']['native-required'], 'native', ('changes', 'flutter', 'windows'))
        require(not build['jobs']['contracts'].get('if') and build['jobs']['contracts'].get('needs') == 'changes')
        require(set(build['jobs']['bundle']['needs']) == {'changes', 'contracts', 'backend', 'web', 'server-quality'})
        for name, filename in (('flutter', 'ci-flutter.yaml'), ('windows', 'flutter-windows.yaml')):
            require(native['jobs'][name] == {'needs': 'changes', 'if': f"needs.changes.outputs.{name} == 'true'",
                                            'uses': './.github/workflows/' + filename})
        for gate, filename in (('backend', 'ci-backend.yaml'), ('web', 'ci-frontend.yaml'), ('contracts', 'ci-contracts.yaml')):
            job = build['jobs'][gate]
            require(job.get('uses') == './.github/workflows/' + filename and job.get('with') == {'release_receipt': 'true'})
            receipts = [s for child in workflows[filename]['jobs'].values() for s in child.get('steps', [])
                        if s.get('uses') == 'actions/upload-artifact@v4'
                        and s.get('with', {}).get('path') == f'.out/checks/{gate}.json']
            require(len(receipts) == 1 and receipts[0].get('if') == 'inputs.release_receipt'
                    and receipts[0]['with']['name'] == f'check-{gate}-' + EXECUTION
                    and receipts[0]['with']['if-no-files-found'] == 'error')
        bundle = build['jobs']['bundle']
        require(bundle.get('concurrency') == {
            'group': 'trusted-server-bundle-${{ github.repository }}', 'cancel-in-progress': 'false'})
        require(bundle.get('if') == MASTER + " && needs.changes.outputs.server_release_impact == 'true'")
        require(all(not build['jobs'][name].get('concurrency') for name in ('changes', 'server-quality')))
        downloads = [s for s in bundle['steps'] if s.get('uses') == 'actions/download-artifact@v4']
        uploads = [s for s in bundle['steps'] if s.get('uses') == 'actions/upload-artifact@v4']
        require([s.get('with') for s in downloads] == [
            {'name': f'check-{gate}-' + EXECUTION, 'path': '.out/checks'}
            for gate in ('backend', 'web', 'contracts')]
            and all(not s.get('if') for s in downloads))
        require(len(uploads) == 2 and uploads[0]['with']['name'] == 'server-' + EXECUTION
                and uploads[1].get('if') == 'always()' and uploads[1]['with'] == {
                    'name':'build-metrics-server-' + EXECUTION,
                    'path':'.out/releases/${{ github.sha }}.build.json',
                    'if-no-files-found':'error','retention-days':'30'})
        from tools.verify.workflows.shared_install import check as shared_install
        from tools.verify.action_pins.policy import normalized
        import yaml
        action = ROOT/'.github/actions/install-trusted-server/action.yaml'
        shared_install(workflows, yaml.load(normalized(action.read_text(encoding='utf-8')), Loader=yaml.BaseLoader))
        for name in ('build-server.yaml', 'ci-backend.yaml', 'ci-frontend.yaml', 'ci-contracts.yaml'):
            for job in workflows[name]['jobs'].values():
                for step in job.get('steps', []):
                    if step.get('uses') == 'actions/upload-artifact@v4':
                        require(all('${{ github.' + field + ' }}' in step.get('with', {}).get('name', '')
                                    for field in ('sha', 'run_id', 'run_attempt')))
    except (KeyError, TypeError, AttributeError, IndexError):
        raise ValueError('Incomplete master producer graph') from None
