"""API writes exclusively to a labeled capacity-bounded disposable tmpfs volume."""
import os
import subprocess
from tools.qa.client_lifecycle.stack import Stack, ready
from tools.qa.client_lifecycle.services import LABEL, remove_owned, run, output


class UploadStack(Stack):
    def __init__(self, root, work, capacity):
        super().__init__(root, work)
        self.capacity, self.api_name = capacity, None
        self.volume, self.keeper = self.owner+'-attachments', self.owner+'-keeper'

    def restart(self):
        self.stop_api()
        if not hasattr(self, 'volume_created'):
            run('docker', 'volume', 'create', '--label', LABEL+'='+self.owner,
                '--opt', 'type=tmpfs', '--opt', 'device=tmpfs', '--opt', 'o=size='+str(self.capacity),
                self.volume, stdout=subprocess.DEVNULL)
            self.resources.append(('volume', self.volume))
            self.volume_created = True
            self.container('keeper', 'postgres:17.6-alpine', '-v', self.volume+':/attachments', command=('sleep', '3600'))
            self.binary = self.work/'api-static'
            docker_arch = output('docker', 'info', '--format', '{{.Architecture}}').strip()
            goarch = {'aarch64': 'arm64', 'arm64': 'arm64', 'x86_64': 'amd64', 'amd64': 'amd64'}.get(docker_arch)
            if not goarch:
                raise RuntimeError('Unsupported disposable Docker architecture')
            run('go', 'build', '-o', str(self.binary), './cmd/api', cwd=self.root/'backend',
                env=dict(os.environ, CGO_ENABLED='0', GOOS='linux', GOARCH=goarch))
        self.environment['ATTACHMENTS_DIRECTORY'] = '/attachments'
        names = ('DATABASE_URL', 'API_ADDR', 'PUBLIC_ORIGIN', 'ATTACHMENTS_DIRECTORY',
                 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'LIVEKIT_PUBLIC_WS_URL',
                 'LIVEKIT_PRIVATE_HTTP_URL', 'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT')
        arguments = [argument for name in names for argument in ('-e', name+'='+self.environment[name])]
        self.container('api', 'postgres:17.6-alpine', '--publish', '127.0.0.1:4820:8080',
                       '--add-host', 'host.docker.internal:host-gateway',
                       '-v', self.volume+':/attachments', '-v', str(self.binary)+':/qa-api:ro',
                       '--entrypoint', '/qa-api', *arguments, network=True)
        self.api_name = self.owner+'-api'
        ready('http://127.0.0.1:4820/api/v1/health')

    def stop_api(self):
        if self.api_name:
            label = output('docker', 'inspect', self.api_name, '--format', '{{index .Config.Labels "'+LABEL+'"}}')
            assert label == self.owner, 'Foreign API container'
            try:
                run('docker', 'stop', '--time', '15', self.api_name, stdout=subprocess.DEVNULL)
                self.last_exit_code = output('docker', 'inspect', self.api_name, '--format', '{{.State.ExitCode}}')
            finally:
                remove_owned(self.api_name, self.owner)
                self.resources.remove(('container', self.api_name))
                self.api_name = None

    def reject_second_writer(self):
        result = subprocess.run(['docker', 'exec', self.api_name, '/qa-api'], capture_output=True, text=True, timeout=10)
        assert result.returncode == 1 and 'attachment volume already has an API writer' in result.stdout, 'Actual second API writer was not rejected'

    def verify_stop_first_handover(self):
        for _ in range(2):
            previous = output('docker', 'inspect', self.api_name, '--format', '{{.Id}}')
            self.stop_api()
            assert self.last_exit_code != '137', 'API shutdown exceeded its graceful deadline'
            exited = subprocess.run(['docker', 'inspect', previous], capture_output=True)
            assert exited.returncode != 0, 'Previous owned API still exists before next writer starts'
            self.restart()
            assert output('docker', 'inspect', self.api_name, '--format', '{{.Id}}') != previous
            self.reject_second_writer()
