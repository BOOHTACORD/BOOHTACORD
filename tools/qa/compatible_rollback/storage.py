"""Read-only logical content fingerprints, not database copies or restore points."""
import hashlib
import json
import subprocess


def output(*args, **kwargs):
    return subprocess.check_output(['docker', *args], **kwargs)


def hash_bytes(value):
    return hashlib.sha256(value).hexdigest()


def container(service):
    result = output('ps', '-q', '--filter', 'label=com.docker.compose.project=voice-platform',
                    '--filter', 'label=com.docker.compose.service=' + service, text=True).strip()
    if not result or '\n' in result:
        raise ValueError('Expected one owned Compose service')
    return result


def sql(query):
    return output('exec', '-i', container('postgres'), 'psql', '-U', 'voice_platform', '-d', 'voice_platform',
                  '-X', '-v', 'ON_ERROR_STOP=1', '-At', input=query.encode()).strip()


def content():
    # Exclude volatile session/read-cursor/lease/worker timestamps. The complete
    # committed synthetic product rows and attachment files remain represented.
    tables = ('users', 'categories', 'channels', 'messages', 'direct_messages', 'direct_message_messages',
              'attachments', 'message_attachments', 'direct_message_attachments')
    values = []
    for table in tables:
        rows = sql(f'SELECT COALESCE(jsonb_agg(row_value ORDER BY row_value::text), \'[]\'::jsonb) FROM (SELECT to_jsonb(t) - ARRAY[\'last_seen_at\',\'last_active_at\',\'last_login_at\'] AS row_value FROM {table} t) s;')
        values.append(table.encode() + b'\0' + rows)
    attachment_root = output('volume', 'inspect', '--format', '{{.Mountpoint}}', 'voice-platform_attachments-data', text=True).strip()
    from pathlib import Path
    root = Path(attachment_root)
    files = [(str(p.relative_to(root)), hash_bytes(p.read_bytes())) for p in sorted(root.rglob('*')) if p.is_file()]
    tls_root = Path(output('volume', 'inspect', '--format', '{{.Mountpoint}}', 'voice-platform_caddy-data', text=True).strip())
    tls = [(str(p.relative_to(tls_root)), hash_bytes(p.read_bytes())) for p in sorted(tls_root.rglob('*'))
           if p.is_file() and p.suffix in ('.crt', '.key', '.pem')]
    if not files or not tls:
        raise ValueError('Actual attachment and TLS content are required')
    proxy_root = Path(output('volume', 'inspect', '--format', '{{.Mountpoint}}', 'voice-platform_caddy-config', text=True).strip())
    config = [(str(p.relative_to(proxy_root)), hash_bytes(p.read_bytes())) for p in sorted(proxy_root.rglob('*')) if p.is_file()]
    if not config:
        raise ValueError('Persisted Caddy config is required')
    return {'database': hash_bytes(b'\n'.join(values)), 'attachments': hash_bytes(json.dumps(files).encode()),
            'tls': hash_bytes(json.dumps(tls).encode()), 'proxy_config': hash_bytes(json.dumps(config).encode()),
            # This migrator replays idempotent SQL and has no migration journal.
            # Inspect actual logical DDL, not a fabricated schema-version table.
            'schema': hash_bytes(sql("""SELECT jsonb_build_object(
              'columns',(SELECT jsonb_agg(row_to_json(c) ORDER BY c.table_name,c.ordinal_position)
                FROM (SELECT table_name,column_name,ordinal_position,data_type,is_nullable,column_default
                      FROM information_schema.columns WHERE table_schema='public') c),
              'constraints',(SELECT jsonb_agg(jsonb_build_array(r.relname,c.conname,pg_get_constraintdef(c.oid)) ORDER BY r.relname,c.conname)
                FROM pg_constraint c JOIN pg_class r ON r.oid=c.conrelid JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname='public'),
              'indexes',(SELECT jsonb_agg(jsonb_build_array(tablename,indexname,indexdef) ORDER BY tablename,indexname) FROM pg_indexes WHERE schemaname='public'),
              'functions',(SELECT jsonb_agg(pg_get_functiondef(p.oid) ORDER BY p.proname,pg_get_function_identity_arguments(p.oid))
                FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f'),
              'triggers',(SELECT jsonb_agg(jsonb_build_array(r.relname,t.tgname,pg_get_triggerdef(t.oid)) ORDER BY r.relname,t.tgname)
                FROM pg_trigger t JOIN pg_class r ON r.oid=t.tgrelid JOIN pg_namespace n ON n.oid=r.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal));"""))}


def observe(phase):
    from tools.release.rollback.identity import identities
    observed = identities()
    return {'phase': phase, 'volumes': {n.removeprefix('volume:'): hash_bytes(v.encode()) for n, v in observed.items() if n.startswith('volume:')},
            'networks': {n.removeprefix('network:'): hash_bytes(v.encode()) for n, v in observed.items() if n.startswith('network:')},
            'content': content()}


def running(phase):
    images, revisions = {}, []
    for name in ('api', 'web'):
        result = json.loads(output('inspect', container(name)))[0]
        images[name] = {'configured': result['Config']['Image'], 'running': result['Image']}
        revisions.append(result['Config']['Labels']['org.opencontainers.image.revision'])
    if revisions[0] != revisions[1]:
        raise ValueError('Component source revisions differ')
    return {'phase': phase, 'revision': revisions[0], 'images': images}
