"""Reuse owned API/PostgreSQL/Tempo/SFU; preserve real production admission."""
import shutil
from tools.qa.mini_player.stack import Stack as ExistingStack
from .proxy import configuration


class Stack(ExistingStack):
    def seed_admin_members(self):
        pass

    def start_api(self):
        self.environment['LIVEKIT_PUBLIC_WS_URL']='wss://localhost:4830'
        super().start_api()

    def container(self, role, image, *args, **options):
        if role == 'proxy':
            site=self.work/'site';site.mkdir()
            shutil.copy2(self.root/'clients/web/node_modules/livekit-client/dist/livekit-client.umd.js',site/'sdk.js')
            shutil.copy2(self.root/'tools/qa/media_revocation/client.js',site/'client.js')
            (site/'index.html').write_text('<!doctype html><html lang="en"><meta charset="utf-8"><title>POC-03 synthetic media</title><body><h1>POC-03 synthetic media</h1><p id="state">idle</p><video id="video" autoplay muted playsinline width="640" height="360"></video><script src="/sdk.js"></script><script src="/client.js"></script></body></html>')
            (self.work/'Caddyfile').write_text(configuration((self.root/'deploy/caddy/Caddyfile').read_text(),self.owner,str(site)))
        return super().container(role, image, *args, **options)
