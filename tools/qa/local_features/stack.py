"""Portable loopback-only proxy for Linux Docker and macOS Colima."""
from tools.qa.critical_client_acceptance.stack import Stack as CriticalStack
from tools.qa.client_lifecycle.stack import Stack as Base

class Stack(CriticalStack):
    def container(self, role, image, *args, **options):
        if role != 'proxy':
            return super().container(role, image, *args, **options)
        config = self.work/'Caddyfile'
        config.write_text('{\n admin off\n auto_https disable_redirects\n}\nhttps://localhost:4810 {\n bind 0.0.0.0\n tls internal\n handle /qa-sfu* {\n  uri strip_prefix /qa-sfu\n  reverse_proxy SFU:4880\n }\n handle /api/* {\n  reverse_proxy API:8080\n }\n handle {\n  root * "ROOT/clients/web/dist"\n  try_files {path} /index.html\n  file_server\n }\n}\n'.replace('SFU', self.owner+'-sfu').replace('API', self.owner+'-api').replace('ROOT', str(self.root)))
        options['network'] = True
        return Base.container(self, role, image, '--publish','127.0.0.1:4810:4810',*args,**options)
