"""Reuse the proven disposable API/SFU stack with exclusive batch identities."""
import secrets
from tools.qa.admin_dialogs.stack import Stack as ExistingStack,Ports
from .policy import PORTS,cleanup

class Stack(ExistingStack):
    def __init__(self,root,work):
        super().__init__(root,work)
        previous=self.owner
        self.owner='qa98325-'+secrets.token_hex(8)
        self.image=self.owner+'-api'
        self.ports=Ports(**PORTS)
        self.environment={k:v.replace(previous,self.owner) for k,v in self.environment.items()}
        self.environment.update(PUBLIC_ORIGIN='https://localhost:5060',LIVEKIT_PUBLIC_WS_URL='ws://localhost:5063',LIVEKIT_PRIVATE_HTTP_URL='http://host.docker.internal:5063')
    def close(self):
        errors=cleanup(self.resources,self.owner)
        if errors:raise RuntimeError('Owned cleanup failed: '+str([r['error_type'] for r in errors]))
