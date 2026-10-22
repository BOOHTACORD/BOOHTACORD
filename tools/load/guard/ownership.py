"""Only the controller's freshly created labelled QA resources can be controlled."""
import re
import subprocess
from tools.qa.client_lifecycle.services import LABEL, output
HUMAN_USERS="FROM users WHERE NOT EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=users.id)"


def validate_identity(owner, database, origin):
    if not re.fullmatch('qa-client-[a-f0-9]{16}', owner) or database != 'qa' or origin != 'https://localhost:4810':
        raise ValueError('Foreign disposable deployment identity')


def owned(stack, role):
    validate_identity(stack.owner, 'qa', stack.environment['PUBLIC_ORIGIN'])
    name = stack.owner+'-'+role
    if role not in ('api', 'db', 'sfu', 'tempo', 'proxy'):
        raise ValueError('Unknown disposable service')
    label = output('docker', 'inspect', name, '--format', '{{index .Config.Labels "'+LABEL+'"}}')
    if label != stack.owner or ('container', name) not in stack.resources:
        raise ValueError('Foreign container ownership')
    return name


def query(stack, sql):
    name = owned(stack, 'db')
    result = subprocess.run(['docker', 'exec', '-i', name, 'psql', '-U', 'qa', '-d', 'qa',
                             '-XAt', '-v', 'ON_ERROR_STOP=1'], input=sql, text=True,
                            capture_output=True, timeout=5)
    if result.returncode:
        raise RuntimeError('Owned disposable database query failed')
    return result.stdout.strip()


def verify_marker(stack, nonce, count):
    rows = query(stack, "SELECT current_database(), owner, nonce, account_count FROM qa_load_fixture;")
    if rows != f'qa|{stack.owner}|{nonce}|{count}':
        raise ValueError('Disposable database marker mismatch')
    users = query(stack, "SELECT count(*), count(*) FILTER (WHERE login='qa_admin' OR login LIKE 'qa_load_%') "+HUMAN_USERS)
    if users != f'{count+1}|{count+1}':
        raise ValueError('Foreign account in disposable dataset')
