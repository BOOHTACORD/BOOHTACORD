"""Repository workflow trust policy; external environment/runner settings need readback."""
import json
import re
from tools.ci.runner_pool.routing import GITHUB_LINUX

UPSTREAM = "github.repository == 'Egkurilov/BOOHTACORD'"
MASTER = UPSTREAM + " && github.ref == 'refs/heads/master'"
QA_PUBLISH = "github.event_name == 'workflow_dispatch' && inputs.publish_qa && " + MASTER


def release_guard(prefix):
    return UPSTREAM + " && (github.ref == 'refs/heads/master' || startsWith(github.ref, 'refs/tags/" + prefix + "'))"


GUARDS = {
    ('native-release-tag.yaml', 'prepare-tag'): MASTER + " && github.event_name == 'workflow_dispatch'",
    ('deploy-production.yaml', 'install'): UPSTREAM + " && needs.route.outputs.has_bundle == 'true' && github.event.workflow_run.conclusion == 'success' && github.event.workflow_run.head_branch == 'master' && github.event.workflow_run.head_repository.full_name == github.repository",
    ('build-server.yaml', 'bundle'): MASTER + " && needs.changes.outputs.server_release_impact == 'true'",
    ('android-release.yaml', 'android-release'): release_guard('android-v'),
    ('windows-release.yaml', 'windows-release'): release_guard('windows-v'),
    ('macos-release.yaml', 'macos-release'): UPSTREAM + " && (startsWith(github.ref, 'refs/tags/macos-v') || (github.ref == 'refs/heads/master' && github.event_name == 'workflow_dispatch' && inputs.dry_run))",
    ('webrtc-macos-sdk.yaml', 'publish'): MASTER + " && github.event_name == 'workflow_dispatch' && inputs.publish_sdk",
    ('promote-windows-client-update.yaml', 'prepare-catalog-pr'): MASTER + " && needs.push-candidate.outputs.changed == 'true'",
    ('promote-windows-client-update.yaml', 'push-candidate'): MASTER,
    ('promote-windows-client-update.yaml', 'candidate-ci'): MASTER + " && needs.push-candidate.outputs.changed == 'true'",
    ('desktop-updater-acceptance.yaml', 'macos-beta-package'): QA_PUBLISH,
    ('windows-updater-acceptance.yaml', 'installed-update'): QA_PUBLISH,
    ('audit-attachment-volume.yaml', 'audit'): MASTER,
    ('qa08-active-upload.yaml', 'sample'): MASTER,
    ('qa11-preflight.yaml', 'inspect'): MASTER,
    ('qa11-preflight.yaml', 'probe'): MASTER + ' && inputs.run_probe',
    ('rehearse-compatible-rollback.yaml', 'rehearse'): MASTER,
    ('install-retained-release.yaml', 'install'): MASTER,
}
DIAGNOSTICS = {('audit-attachment-volume.yaml','audit'),('qa08-active-upload.yaml','sample'),('qa11-preflight.yaml','inspect')}

WRITERS = {('android-release.yaml', 'android-release'), ('windows-release.yaml', 'windows-release'),
           ('native-release-tag.yaml', 'prepare-tag'),
           ('macos-release.yaml', 'macos-release'), ('webrtc-macos-sdk.yaml', 'publish'),
           ('promote-windows-client-update.yaml', 'prepare-catalog-pr'),
           ('desktop-updater-acceptance.yaml', 'macos-beta-package'),
           ('windows-updater-acceptance.yaml', 'installed-update')}


def require(value):
    if not value:
        raise ValueError('Actions trust/permission/credential policy violation')


HOSTED = {GITHUB_LINUX, 'windows-2022', 'macos-26', 'macos-26-intel'}


def sensitive(value):
    expressions = re.findall(r'\$\{\{(.*?)\}\}', json.dumps(value), re.DOTALL)
    return any(re.search(r'\bsecrets\b', expression) and
               not re.fullmatch(r"\s*secrets\.GITHUB_TOKEN\s*", expression) for expression in expressions)


def hosted_runner(identity, job):
    runner = job.get('runs-on')
    if runner is None:
        return str(job.get('uses', '')).startswith('./.github/workflows/')
    if identity == ('webrtc-macos-sdk.yaml', 'build'):
        rows = job.get('strategy', {}).get('matrix', {}).get('include', [])
        return runner == '${{ matrix.runner }}' and rows == [
            {'arch': 'arm64', 'runner': 'macos-26'}, {'arch': 'x64', 'runner': 'macos-26-intel'}]
    return isinstance(runner, str) and runner in HOSTED


def check(workflows):
    for name, workflow in workflows.items():
        require('pull_request_target' not in workflow['on'])
        require(not sensitive({k: v for k, v in workflow.items() if k != 'jobs'}))
        require(isinstance(workflow.get('permissions'), dict))
        require(all(v == 'read' for v in workflow['permissions'].values()))
        untrusted = bool({'pull_request', 'merge_group'} & set(workflow['on']))
        for job_id, job in workflow['jobs'].items():
            identity = (name, job_id)
            require(job.get('continue-on-error') in (None, False, 'false'))
            permissions = job.get('permissions', workflow['permissions'])
            require(isinstance(permissions, dict) and job.get('secrets') != 'inherit')
            expected = {'contents': 'write'}
            promotion_permissions={
                'push-candidate':{'contents':'write','pull-requests':'read'},
                'candidate-ci':{'contents':'read','actions':'write'},
                'prepare-catalog-pr':{'contents':'read','actions':'read','pull-requests':'write'}}
            special=identity[0]=='promote-windows-client-update.yaml' and identity[1] in promotion_permissions
            if special: expected=promotion_permissions[identity[1]]
            require(permissions == expected if identity in WRITERS or special else
                    all(value == 'read' for value in permissions.values()))
            require(hosted_runner(identity, job))
            secrets = sensitive(job)
            if untrusted:
                require(not secrets and all(v == 'read' for v in permissions.values()))
            if identity in GUARDS:
                require(job.get('if') == GUARDS[identity] and job.get('environment') == ('production-diagnostics' if identity in DIAGNOSTICS else 'production'))
            if secrets:
                require(identity in GUARDS and job.get('environment') == ('production-diagnostics' if identity in DIAGNOSTICS else 'production'))
            for step in job.get('steps', []):
                require(step.get('continue-on-error') in (None, False, 'false'))
                if step.get('uses', '').startswith('actions/checkout@'):
                    expected = 'true' if identity == ('promote-windows-client-update.yaml', 'push-candidate') else 'false'
                    require(step.get('with', {}).get('persist-credentials') == expected)
