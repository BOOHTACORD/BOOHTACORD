"""Fixed operator capabilities and exact public, non-shell input contracts."""
import re

REPO='BOOHTACORD/BOOHTACORD'
OPERATIONS={
    'audit':('audit-attachment-volume.yaml','production-diagnostics','read-only','read-only-observation',180),
    'sample':('qa08-active-upload.yaml','production-diagnostics','read-only','upload-in-progress',240),
    'preflight':('qa11-preflight.yaml','production-diagnostics','read-only','read-only-observation',120),
    'probe':('qa11-preflight.yaml','production','mutation','temporary-build-probe',600),
    'rollback':('rehearse-compatible-rollback.yaml','production','mutation','rollback-and-restore',900),
}


def require(value):
    if not value:raise ValueError('Operator source, approval, input or capability is invalid')


def sha(value):require(isinstance(value,str) and re.fullmatch('[0-9a-f]{40}',value));return value


def request(operation,env):
    require(operation in OPERATIONS);workflow,environment,risk,ack,timeout=OPERATIONS[operation]
    require(env.get('GITHUB_REPOSITORY')==REPO and env.get('GITHUB_EVENT_NAME')=='workflow_dispatch'
            and env.get('GITHUB_REF')=='refs/heads/master' and env.get('GITHUB_RUN_ATTEMPT')=='1')
    source=sha(env.get('GITHUB_SHA'));expected=sha(env.get('EXPECTED_SOURCE'))
    for key in ('GITHUB_RUN_ID','GITHUB_ACTOR_ID'):require(re.fullmatch('[1-9][0-9]{0,19}',env.get(key,'')))
    dry=env.get('OPERATOR_DRY_RUN');require(dry in ('true','false'))
    if dry=='false':require(env.get('OPERATOR_CONFIRM')==ack)
    previous=None;count=None
    if operation=='rollback':
        previous=sha(env.get('PREVIOUS_SOURCE'));require(previous!=expected)
        if dry=='false':require(env.get('OBSERVERS_CONFIRMED')=='two-browsers-ready')
    if operation=='sample':
        value=env.get('QA08_SAMPLE_COUNT','90');require(re.fullmatch('[0-9]{1,3}',value));count=int(value);require(2<=count<=120)
    return dict(operation=operation,workflow=workflow,environment=environment,risk=risk,timeout=timeout,
                source_revision=source,expected_source=expected,previous_source=previous,sample_count=count,
                dry_run=dry=='true',run_id=env['GITHUB_RUN_ID'],run_attempt='1',actor_id=int(env['GITHUB_ACTOR_ID']))


def remote_request(command):
    require(isinstance(command,str) and len(command)<=150)
    parts=command.split(' ');require(len(parts) in (3,4) and parts[0]=='boohtacord-operator-v1')
    operation=parts[1];require(operation in ('audit','sample','preflight'));source=sha(parts[2]);count=None
    if operation=='sample':
        require(len(parts)==4 and re.fullmatch('[0-9]{1,3}',parts[3]));count=int(parts[3]);require(2<=count<=120)
    else:require(len(parts)==3)
    return operation,source,count
