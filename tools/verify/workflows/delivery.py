"""Policy checks for the producer/consumer graph, independent of display-step names."""
from pathlib import Path
import yaml
from tools.verify.action_pins.policy import normalized
from tools.verify.action_pins.trust import GUARDS
from tools.release.delivery.routing import GATES as PRODUCER_GATE_NAMES
from .selection import require
from . import release_routing

GATES = {'ci-backend.yaml', 'ci-frontend.yaml', 'ci-contracts.yaml'}
WRITERS = ('deploy-production.yaml', 'install-retained-release.yaml', 'rehearse-compatible-rollback.yaml')


def commands(job):
    return '\n'.join(step.get('run', '') for step in job.get('steps', []))


def check(workflows):
    from tools.ci.master_quality.workflow import validate as validate_master
    validate_master(workflows)
    from tools.ci.backend_gates.workflow import validate as validate_backend
    validate_backend(workflows['ci-backend.yaml'])
    from tools.ci.backend_gates.shadow_workflow import validate as validate_backend_shadow
    validate_backend_shadow(workflows['backend-ci-shadow.yaml'])
    from tools.ci.web_suites.workflow import validate as validate_web
    validate_web(workflows['ci-frontend.yaml'])
    from tools.ci.web_suites.shadow_workflow import validate as validate_shadow
    validate_shadow(workflows['web-ci-shadow.yaml'])
    from tools.ops.operator.workflow import validate as validate_operators
    validate_operators(workflows)
    from tools.ci.observability.workflow import validate as validate_triage
    validate_triage(workflows)
    from tools.ci.migration.workflow import validate as validate_cutover
    validate_cutover(workflows)
    build = workflows['build-server.yaml']
    gates = {name for name, job in build['jobs'].items() if job.get('uses', '').rsplit('/', 1)[-1] in GATES
             and job.get('with', {}).get('release_receipt') == 'true'}
    builders = [job for job in build['jobs'].values() if 'tools/release/delivery/build.sh' in commands(job)]
    require(len(gates) == 3 and len(builders) == 1, 'One builder and all receipt-producing gates are required')
    qualified = []
    for caller in gates:
        job = build['jobs'][caller]
        callee = workflows[job['uses'].rsplit('/', 1)[-1]]
        receipts = [(name, child) for name, child in callee['jobs'].items()
                    if 'tools.ci.receipts.run' in commands(child)]
        require(len(receipts) == 1, 'Each producer gate needs one receipt-emitting child')
        child, definition = receipts[0]
        qualified.append(job.get('name', caller) + ' / ' + definition.get('name', child))
    require(len(set(qualified)) == 3 and set(qualified) == set(PRODUCER_GATE_NAMES),
            'Producer job identities must match the runtime route decoder')
    for name in ('changes', 'bundle', 'server-quality'):
        require(build['jobs'][name].get('name', name) == name, 'Producer root job identity drift')
    builder = builders[0]
    require(builder.get('runs-on') == 'ubuntu-24.04',
            'Signed builds must use the pinned GitHub-hosted Linux runner')
    require(set(builder.get('needs', [])) == gates | {'changes', 'server-quality'}, 'Builder must depend on all source-bound receipts and master quality')
    require(builder.get('if') == GUARDS[('build-server.yaml', 'bundle')] and builder.get('environment') == 'production',
            'Only protected master builds can use the production signer')
    require(build['concurrency'] == {
        'group': 'server-build-${{ github.ref }}-${{ github.sha }}', 'cancel-in-progress': 'true'},
        'Only duplicate same-source master producers may supersede one another')
    require(builder.get('concurrency') == {
        'group': 'trusted-server-bundle-${{ github.repository }}', 'cancel-in-progress': 'false'},
        'Only release-qualified bundles enter the shared non-cancellable signer queue')
    uploads = [step['with'] for step in builder['steps'] if step.get('uses') == 'actions/upload-artifact@v4']
    require(len(uploads) == 2 and uploads[0]['name'] == 'server-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'
            and uploads[0]['if-no-files-found'] == 'error'
            and uploads[1] == {'name':'build-metrics-server-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}',
                              'path':'.out/releases/${{ github.sha }}.build.json',
                              'if-no-files-found':'error','retention-days':'30'},
            'Builder must retain the exact release pair and a separate sanitized timing artifact')
    for name in WRITERS:
        workflow = workflows[name]
        expected_lock = {'group': 'v-bootybay-production', 'cancel-in-progress': 'false'}
        if name != 'deploy-production.yaml':
            require(workflow.get('concurrency') == expected_lock,
                    'Retained install/recovery/rollback must share the non-cancellable production lock')
        for job_name, job in workflow['jobs'].items():
            if name == 'deploy-production.yaml' and job_name == 'route':
                continue
            if name == 'deploy-production.yaml':
                require(job.get('concurrency') == expected_lock,
                        'Every automatic production writer must hold the shared non-cancellable job lock')
            require(job.get('environment') == 'production', 'Production environment protection is required')
            require(not any(word in commands(job) for word in ('build_images', 'legacy_transfer', 'docker build', 'npm ', 'go build')),
                    'Production writer must not build from source')
    deploy = workflows['deploy-production.yaml']
    release_routing.check(build, deploy, gates)
    require(deploy['on']['workflow_run'] == {'workflows': ['Build server'], 'branches': ['master'], 'types': ['completed']},
            'Deployment must consume completed master builds')
    installer = deploy['jobs']['install']
    for guard in ("conclusion == 'success'", "head_branch == 'master'", 'head_repository.full_name == github.repository'):
        require(guard in installer.get('if', ''), 'Untrusted producer completion must not deploy')
    from .shared_install import check as shared_install
    action = Path(__file__).resolve().parents[3]/'.github/actions/install-trusted-server/action.yaml'
    shared_install(workflows, yaml.load(normalized(action.read_text(encoding='utf-8')), Loader=yaml.BaseLoader))


def main():
    root = Path(__file__).resolve().parents[3]
    workflows = {path.name: yaml.load(normalized(path.read_text(encoding='utf-8')), Loader=yaml.BaseLoader)
                 for path in (root / '.github/workflows').glob('*.yaml')}
    check(workflows)
    print('Signed builder, retained artifact and sole production-writer policy: OK')


if __name__ == '__main__': main()
