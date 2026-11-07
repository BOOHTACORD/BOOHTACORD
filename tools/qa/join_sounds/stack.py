"""Feature-specific real API + private normalizer acceptance stack."""
import subprocess
from tools.qa.local_features.stack import Stack as Base
from tools.qa.client_lifecycle.services import LABEL, run

class Stack(Base):
    def start(self):
        self.worker_image = 'codex-join-sound-worker:qa'
        self.environment['JOIN_SOUND_PROCESSOR_URL'] = 'http://join-sound-processor:8090/normalize'
        self.processing_network = self.owner+'-sound-processing'
        self.worker_started = False
        super().start()

    def container(self, role, image, *args, **options):
        if role == 'api' and not self.worker_started:
            run('docker', 'network', 'create', '--internal', '--label', LABEL+'='+self.owner,
                self.processing_network, stdout=subprocess.DEVNULL)
            self.resources.append(('network',self.processing_network))
            run('docker','run','-d','--name',self.owner+'-sound','--label',LABEL+'='+self.owner,
                '--network',self.processing_network,'--network-alias','join-sound-processor','--read-only','--user','65532:65532',
                '--cap-drop','ALL','--security-opt','no-new-privileges:true','--cpus','1',
                '--memory','256m','--pids-limit','64','--tmpfs','/tmp:size=16m,mode=1777,noexec,nosuid,nodev',
                self.worker_image,stdout=subprocess.DEVNULL)
            self.resources.append(('container',self.owner+'-sound')); self.worker_started = True
        result = super().container(role,image,*args,**options)
        if role == 'api': run('docker','network','connect',self.processing_network,self.owner+'-api')
        return result
