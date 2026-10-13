"""Reuse the proven disposable API/SFU stack with exclusive batch identities."""
import secrets
from tools.qa.admin_dialogs.stack import Stack as ExistingStack,Ports
from .policy import PORTS,cleanup,backend_arguments

class Stack(ExistingStack):
    def __init__(self,root,work,*,backend_copy=None):
        super().__init__(root,work)
        self.backend_copy=backend_copy
        previous=self.owner
        self.owner='qa98325-'+secrets.token_hex(8)
        self.image=self.owner+'-api'
        self.ports=Ports(**PORTS)
        self.environment={k:v.replace(previous,self.owner) for k,v in self.environment.items()}
        self.environment.update(PUBLIC_ORIGIN='https://localhost:5060',LIVEKIT_PUBLIC_WS_URL='wss://localhost:5060/sfu',LIVEKIT_PRIVATE_HTTP_URL='http://host.docker.internal:5063')
    def start(self):
        # Process-local adapter for the inherited builder: only its exact API
        # context changes. Shared tool files and other workers are untouched.
        import tools.qa.admin_dialogs.stack as inherited
        original=inherited.run
        if self.backend_copy is not None:
            def pinned_run(*args,**kwargs):
                return original(*backend_arguments(args,self.root/'backend',self.backend_copy),**kwargs)
            inherited.run=pinned_run
        try:super().start()
        finally:inherited.run=original
        config=self.work/'Caddyfile'
        text=config.read_text().replace('  handle /api/* {','  handle_path /sfu* {\n    reverse_proxy host.docker.internal:5063\n  }\n  handle /api/* {')
        config.write_text(text)
        import subprocess
        subprocess.run(['docker','restart',self.owner+'-proxy'],check=True,stdout=subprocess.DEVNULL)
        from tools.qa.admin_dialogs.stack import ready
        ready('https://localhost:5060/api/v1/health')
    def close(self):
        errors=cleanup(self.resources,self.owner)
        if errors:raise RuntimeError('Owned cleanup failed: '+str([r['error_type'] for r in errors]))
