"""Policy checks for the producer/consumer graph, independent of display-step names."""
from pathlib import Path
import yaml
from .selection import require
from . import release_routing

GATES = {'ci-backend.yaml', 'ci-frontend.yaml', 'ci-contracts.yaml'}
WRITERS = ('deploy-production.yaml', 'install-retained-release.yaml', 'rehearse-compatible-rollback.yaml')


def commands(job):
    return '\n'.join(step.get('run', '') for step in job.get('steps', []))


def check(workflows):
    build = workflows['build-server.yaml']
    gates = {name for name, job in build['jobs'].items() if job.get('uses', '').rsplit('/', 1)[-1] in GATES
             and job.get('with', {}).get('release_receipt') == 'true'}
    builders = [job for job in build['jobs'].values() if 'tools/release/delivery/build.sh' in commands(job)]
    require(len(gates) == 3 and len(builders) == 1, 'One builder and all receipt-producing gates are required')
    builder = builders[0]
    require(set(builder.get('runs-on', [])) == {'self-hosted', 'linux', 'x64', 'boohtacord-builder'},
            'Signed builds require the dedicated Docker-capable builder runner')
    require(set(builder.get('needs', [])) == gates | {'changes'}, 'Builder must depend on all source-bound receipts')
    require(builder.get('if') == "github.ref == 'refs/heads/master' && needs.changes.outputs.server_release_impact == 'true'" and builder.get('environment') == 'production',
            'Only protected master builds can use the production signer')
    require(build['concurrency']['cancel-in-progress'] == 'true', 'Obsolete builds must be cancellable')
    uploads = [step['with'] for step in builder['steps'] if step.get('uses') == 'actions/upload-artifact@v4']
    require(len(uploads) == 1 and uploads[0]['name'] == 'server-${{ github.sha }}'
            and uploads[0]['if-no-files-found'] == 'error', 'Builder must retain the exact release artifact')
    for name in WRITERS:
        workflow = workflows[name]
        require(workflow['concurrency'] == {'group': 'v-bootybay-production', 'cancel-in-progress': 'false'},
                'Install/recovery/rollback must share a non-cancellable production lock')
        for job_name, job in workflow['jobs'].items():
            if name == 'deploy-production.yaml' and job_name == 'route':
                continue
            require(job.get('environment') == 'production', 'Production environment protection is required')
            require(not any(word in commands(job) for word in ('build_images', 'legacy_transfer', 'docker build', 'npm ', 'go build')),
                    'Production writer must not build from source')
    deploy = workflows['deploy-production.yaml']
    release_routing.check(build, deploy, gates)
    require(deploy['on']['workflow_run'] == {'workflows': ['Build server'], 'branches': ['master'], 'types': ['completed']},
            'Deployment must consume completed master builds')
    installer = next(job for job in deploy['jobs'].values() if 'tools/release/delivery/transfer.sh' in commands(job))
    for guard in ("conclusion == 'success'", "head_branch == 'master'", 'head_repository.full_name == github.repository'):
        require(guard in installer.get('if', ''), 'Untrusted producer completion must not deploy')
    for name in WRITERS[:2]:
        jobs = workflows[name]['jobs'].values()
        require(any('tools.release.delivery.provenance' in commands(job) for job in jobs), 'Artifact producer provenance must be checked')


def main():
    root = Path(__file__).resolve().parents[3]
    workflows = {path.name: yaml.load(path.read_text(encoding='utf-8'), Loader=yaml.BaseLoader)
                 for path in (root / '.github/workflows').glob('*.yaml')}
    check(workflows)
    print('Signed builder, retained artifact and sole production-writer policy: OK')


if __name__ == '__main__': main()
