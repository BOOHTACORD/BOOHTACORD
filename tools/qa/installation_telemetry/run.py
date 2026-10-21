"""Owned PostgreSQL/Tempo/Collector/Prometheus acceptance; never uses production."""
import json
import os
from pathlib import Path
import secrets
import platform
import shutil
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[3]


def run():
    out = ROOT / '.out/installation-telemetry-336'
    out.mkdir(parents=True, exist_ok=True)
    project = 'boohtacord-it336-' + secrets.token_hex(4)
    password = secrets.token_hex(24)
    fleet = ROOT / 'docker/observability/fleet'
    # A disposable single-binary fixture has no peer rollout convergence wait.
    # Ring readiness still has to pass; no health response is mocked.
    tempo_config = out / 'tempo-single-node.yaml'
    tempo_config.write_text((fleet / 'tempo.yaml').read_text().replace(
        'ingester: {trace_idle_period: 10s, max_block_duration: 5m}',
        'ingester: {trace_idle_period: 1s, max_block_duration: 1m, lifecycler: {min_ready_duration: 0s}}'))
    config = {'services': {
        'postgres': {'image': 'postgres:17.6-alpine', 'environment': {'POSTGRES_USER': 'qa336', 'POSTGRES_PASSWORD': password}, 'ports': ['127.0.0.1::5432'], 'tmpfs': ['/var/lib/postgresql/data']},
        'tempo': {'image': 'grafana/tempo:2.10.3', 'command': ['-config.file=/etc/tempo/config.yaml'], 'volumes': [str(tempo_config) + ':/etc/tempo/config.yaml:ro'], 'ports': ['127.0.0.1::3200', '127.0.0.1::4318']},
        'collector': {'image': 'otel/opentelemetry-collector:0.161.0', 'command': ['--config=/etc/otelcol/config.yaml'], 'volumes': [str(fleet / 'collector.yaml') + ':/etc/otelcol/config.yaml:ro'], 'ports': ['127.0.0.1::4318']},
        'prometheus': {'image': 'prom/prometheus:v3.11.2', 'command': ['--config.file=/etc/prometheus/prometheus.yaml'], 'volumes': [str(fleet / 'prometheus.yaml') + ':/etc/prometheus/prometheus.yaml:ro', str(fleet / 'alerts.yaml') + ':/etc/prometheus/alerts.yaml:ro'], 'ports': ['127.0.0.1::9090']},
    }}
    sfu_config = out / 'livekit-synthetic.yaml'
    sfu_config.write_text('port: 7880\nprometheus_port: 6789\nrtc:\n  tcp_port: 7881\n  use_external_ip: false\nkeys:\n  qa336: synthetic-local-fixture-only-key-336\n')
    for name in ('sfua','sfub'):
        config['services'][name] = {'image':'livekit/livekit-server:v1.13.7','command':['--config','/etc/livekit.yaml','--node-ip','127.0.0.1'], 'volumes':[str(sfu_config)+':/etc/livekit.yaml:ro'],'ports':['127.0.0.1::6789']}
    path = out / 'compose.private.json'
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        json.dump(config, stream)
    context = os.environ.get('DOCKER_CONTEXT', 'colima-boohtacord-qa' if platform.system() == 'Darwin' else 'default')
    os.environ['DOCKER_CONTEXT'] = context
    base = ([shutil.which('docker-compose')] if shutil.which('docker-compose') else ['docker', 'compose']) + ['-p', project, '-f', str(path)]

    def command(args, timeout=30):
        result = subprocess.run(base + args, capture_output=True, text=True, timeout=timeout)
        if result.returncode:
            raise RuntimeError('Owned QA dependency operation failed: ' + args[0])
        return result.stdout.strip()

    def endpoint(service, port):
        return 'http://' + command(['port', service, str(port)])

    status = 'FAIL'
    try:
        print('Starting owned #336 dependencies', flush=True)
        command(['up', '-d'], timeout=180)
        deadline = time.monotonic() + (20 if os.environ.get('BOOHTACORD_QA_DIAGNOSE_UNREADY') == '1' else 100)
        readiness = False
        tempo = endpoint('tempo', 3200)
        while True:
            try:
                with urllib.request.urlopen(tempo + '/ready', timeout=3) as response:
                    if response.status == 200:
                        readiness = True
                        break
            except Exception:
                pass
            if time.monotonic() >= deadline:
                if os.environ.get('BOOHTACORD_QA_DIAGNOSE_UNREADY') == '1':
                    print('Tempo readiness FAIL; running separate functional diagnostics, not accepting readiness', flush=True)
                    break
                raise RuntimeError('Owned Tempo readiness did not become healthy')
            time.sleep(2)
        env = os.environ.copy()
        address = command(['port', 'postgres', '5432'])
        env.update(BOOHTACORD_TELEMETRY_TEST_DATABASE_URL='postgres://qa336:' + password + '@' + address + '/postgres?sslmode=disable',
                   BOOHTACORD_TELEMETRY_TEST_TEMPO=tempo,
                   BOOHTACORD_TELEMETRY_TEST_OTLP=endpoint('tempo', 4318),
                   BOOHTACORD_TELEMETRY_TEST_COLLECTOR=endpoint('collector', 4318),
                   BOOHTACORD_TELEMETRY_TEST_PROMETHEUS=endpoint('prometheus', 9090),
                   BOOHTACORD_TELEMETRY_TEST_SFU_A=endpoint('sfua',6789),
                   BOOHTACORD_TELEMETRY_TEST_SFU_B=endpoint('sfub',6789))
        print('Running two-installation real-storage acceptance', flush=True)
        result = subprocess.run(['go', 'test', '-tags=installation_acceptance', '-count=1', '-timeout=180s', '-v', './internal/observability/installation_acceptance'], cwd=ROOT / 'backend', env=env, capture_output=True, text=True, timeout=200)
        (out / 'acceptance.log').write_text(result.stdout + result.stderr)
        print(result.stdout, flush=True)
        if result.returncode or '--- SKIP:' in result.stdout or result.stdout.count('--- PASS:') != 2:
            raise RuntimeError('Two-installation acceptance failed; inspect sanitized acceptance.log')
        status = 'PASS' if readiness else 'BLOCKED'
    finally:
        logs = subprocess.run(base + ['logs', '--no-color', '--tail=30', 'tempo'], capture_output=True, text=True, timeout=15)
        (out / 'tempo-diagnostics.log').write_text(logs.stdout)
        cleanup = subprocess.run(base + ['down', '-v', '--remove-orphans'], capture_output=True, timeout=60)
        path.unlink(missing_ok=True)
        receipt = {'issue': 336, 'status': status, 'cleanup': 'PASS' if cleanup.returncode == 0 else 'FAIL',
                   'scope': 'Two independent PostgreSQL databases, signed enrollment over verified TLS, real Tempo tenants and real Prometheus OTLP series; synthetic IDs only.',
                   'source_revision': subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), 'production_mutations': False, 'readiness': 'PASS' if locals().get('readiness') else 'FAIL'}
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    if status != 'PASS':
        raise RuntimeError('Functional diagnostics do not override failed readiness')


if __name__ == '__main__':
    run()
