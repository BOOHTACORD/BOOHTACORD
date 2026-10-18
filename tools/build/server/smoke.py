"""Run the built images against an isolated disposable PostgreSQL instance."""
import json
import subprocess
import time
import uuid
from urllib.request import urlopen
from tools.build.web.assets import verify_png
from tools.build.web.audio_assets import verify_served_audio

OPERATORS = ("api", "migrate", "bootstrap-admin", "recover-admin", "recover-last-admin-access",
             "maintenance-admission", "cleanup-stale-staging", "cleanup-unattached-attachments", "cleanup-hidden-attachments")


def docker(*args):
    return subprocess.check_output(["docker", *args], text=True).strip()


def wait_url(url, *, png=False):
    for attempt in range(30):
        try:
            with urlopen(url, timeout=2) as response:
                body = response.read()
                if png:
                    verify_png(response.headers.get("Content-Type", ""), body)
                elif response.status != 200 or json.loads(body).get("status") != "ok":
                    raise ValueError("API health response differs")
                return
        except (OSError, ValueError):
            if attempt == 29: raise
            time.sleep(1)


def wait_database(database, *, attempts=30):
    # The entrypoint's temporary init server accepts Unix sockets before the
    # final server listens on TCP. Migrations connect over TCP, never that socket.
    for attempt in range(attempts):
        if subprocess.run(['docker', 'exec', database, 'pg_isready', '--host=127.0.0.1',
                           '-U', 'voice_platform_test'], capture_output=True).returncode == 0:
            return
        if attempt == attempts - 1:
            raise RuntimeError('Smoke PostgreSQL TCP did not become ready')
        time.sleep(1)


def run_smoke(receipts, output):
    suffix = uuid.uuid4().hex[:12]
    network, database = "release-smoke-" + suffix, "db-" + suffix
    containers = []
    api, web = [receipts[name]["index_digest"] for name in ("api", "web")]
    docker("network", "create", network)
    try:
        containers.append(docker("run", "-d", "--rm", "--name", database, "--network", network,
                                 "-e", "POSTGRES_DB=voice_platform_test", "-e", "POSTGRES_USER=voice_platform_test",
                                 "-e", "POSTGRES_PASSWORD=test-only-password", "postgres:17.6-alpine"))
        wait_database(database)
        dsn = f"DATABASE_URL=postgres://voice_platform_test:test-only-password@{database}:5432/voice_platform_test?sslmode=disable"
        for _ in range(2):
            docker("run", "--rm", "--network", network, "-e", dsn, "--entrypoint", "/migrate", api)
        probe = docker("create", api)
        containers.append(probe)
        for command in OPERATORS:
            docker("cp", probe + ":/" + command, str(output / command))
            if not (output / command).is_file(): raise ValueError("Missing operator binary: " + command)
        for option in ("--enable", "--disable"):
            docker("run", "--rm", "--network", network, "-e", dsn, "--entrypoint", "/maintenance-admission", api, option)
        api_container = docker("run", "-d", "--rm", "--network", network, "-p", "127.0.0.1::8080", "-e", dsn,
                               "-e", "PUBLIC_ORIGIN=https://smoke.invalid", "-e", "LIVEKIT_PUBLIC_WS_URL=wss://smoke.invalid",
                               "-e", "LIVEKIT_PRIVATE_HTTP_URL=http://unavailable.invalid", "-e", "LIVEKIT_API_KEY=smoke-key",
                               "-e", "LIVEKIT_API_SECRET=smoke-secret", "-e", "ATTACHMENTS_DIRECTORY=/attachments",
                               "--tmpfs", "/attachments:uid=65532,gid=65532,mode=700", api)
        containers.append(api_container)
        web_container = docker("run", "-d", "--rm", "-p", "127.0.0.1::80", web)
        containers.append(web_container)
        for container, port, endpoint, png in ((api_container, 8080, "/api/v1/health", False), (web_container, 80, "/favicon.png", True)):
            host_port = docker("inspect", "--format", '{{(index (index .NetworkSettings.Ports "' + str(port) + '/tcp") 0).HostPort}}', container)
            base_url = "http://127.0.0.1:" + host_port
            wait_url(base_url + endpoint, png=png)
            if png: verify_served_audio(base_url)
    finally:
        for container in reversed(containers):
            subprocess.run(["docker", "rm", "-f", "-v", container], capture_output=True)
        subprocess.run(["docker", "network", "rm", network], capture_output=True)
