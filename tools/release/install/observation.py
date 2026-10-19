"""Read-only installed-source evidence; never export rows, file contents or secrets."""
import hashlib
import json
import re
from .docker import docker
from tools.release.bundle.manifest import require
from tools.release.delivery.commands import execute

VOLUMES = ('postgres-data', 'attachments-data', 'caddy-data', 'caddy-config')
CATALOG = """SELECT encode(sha256(convert_to((jsonb_build_object(
 'columns',(SELECT jsonb_agg(row_to_json(c) ORDER BY c.table_name,c.ordinal_position)
 FROM (SELECT table_name,column_name,ordinal_position,data_type,is_nullable,column_default
 FROM information_schema.columns WHERE table_schema='public') c),
 'constraints',(SELECT jsonb_agg(jsonb_build_array(r.relname,c.conname,pg_get_constraintdef(c.oid)) ORDER BY r.relname,c.conname)
 FROM pg_constraint c JOIN pg_class r ON r.oid=c.conrelid JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname='public'),
 'indexes',(SELECT jsonb_agg(jsonb_build_array(tablename,indexname,indexdef) ORDER BY tablename,indexname) FROM pg_indexes WHERE schemaname='public'),
 'functions',(SELECT jsonb_agg(pg_get_functiondef(p.oid) ORDER BY p.proname,pg_get_function_identity_arguments(p.oid))
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f'),
 'triggers',(SELECT jsonb_agg(jsonb_build_array(r.relname,t.tgname,pg_get_triggerdef(t.oid)) ORDER BY r.relname,t.tgname)
 FROM pg_trigger t JOIN pg_class r ON r.oid=t.tgrelid JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal)))::text,'UTF8')),'hex');"""


def container(service):
    value = docker('ps', '-q', '--filter', 'label=com.docker.compose.project=voice-platform',
                   '--filter', 'label=com.docker.compose.service=' + service)
    require(bool(value) and '\n' not in value, 'Expected one running service for readback')
    return value


def volumes():
    result = {}
    for name in VOLUMES:
        owner = 'voice-platform_' + name
        rows = json.loads(docker('volume', 'inspect', owner))
        require(isinstance(rows, list) and len(rows) == 1 and isinstance(rows[0], dict), 'Ambiguous persistent volume')
        row = rows[0]
        fields = ('Name', 'Driver', 'Mountpoint', 'CreatedAt', 'Scope')
        require(row.get('Name') == owner and all(isinstance(row.get(k), str) and row[k] for k in fields),
                'Persistent volume identity is unavailable')
        value = {key: row[key] for key in fields}
        result[name] = hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return result


def sources(revision):
    result = {}
    for name in ('api', 'web'):
        rows = json.loads(docker('inspect', container(name)))
        require(isinstance(rows, list) and len(rows) == 1, 'Ambiguous running source')
        row = rows[0]
        require(row.get('State', {}).get('Running') is True, 'Installed service is not running')
        source = row.get('Config', {}).get('Labels', {}).get('org.opencontainers.image.revision')
        if not isinstance(source, str) or not re.fullmatch('[a-f0-9]{40}', source):
            source = docker('image', 'inspect', '--format', '{{index .Config.Labels "org.opencontainers.image.revision"}}', row['Image'])
        require(source == revision, 'Running service source differs from signed release')
        result[name] = source
    return result


def health(directory):
    hosts = [line.removeprefix('PUBLIC_HOST=') for line in (directory/'.env').read_text().splitlines()
             if line.startswith('PUBLIC_HOST=')]
    require(len(hosts) == 1 and len(hosts[0]) <= 253 and
            re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?', hosts[0]), 'Invalid health target')
    host = hosts[0]
    execute(['curl', '--fail', '--silent', '--show-error', '--connect-timeout', '5', '--max-time', '15',
             '--resolve', host + ':443:127.0.0.1', '--output', '/dev/null', 'https://' + host + '/api/v1/health'], 20)
    return 'PASS'


def schema():
    result = execute(['docker', 'exec', '-e', 'PGOPTIONS=-c default_transaction_read_only=on', container('postgres'),
                      'sh', '-c', 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -X -v ON_ERROR_STOP=1 -At -c "$1"',
                      'readback', CATALOG], 20, capture_limit=128)
    value = result.decode('ascii').strip()
    require(re.fullmatch('[a-f0-9]{64}', value), 'Schema catalog fingerprint is unavailable')
    return value
