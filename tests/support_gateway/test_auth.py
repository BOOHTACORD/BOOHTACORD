import base64
import hashlib
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from support_gateway.auth import authenticate, canonical
from support_gateway.store import Store

class AuthTests(unittest.TestCase):
    def test_signed_request_binds_path_body_time_and_nonce(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);key=root/'key';pub=root/'pub';body=root/'body';sig=root/'sig'
            subprocess.run(['openssl','genpkey','-algorithm','ED25519','-out',str(key)],check=True,capture_output=True)
            subprocess.run(['openssl','pkey','-in',str(key),'-pubout','-outform','DER','-out',str(pub)],check=True,capture_output=True)
            now=int(time.time());nonce='a'*32;payload=b'{"synthetic":true}'
            body.write_bytes(canonical('POST','/support/v1/messages',now,nonce,payload))
            subprocess.run(['openssl','pkeyutl','-sign','-rawin','-inkey',str(key),'-in',str(body),'-out',str(sig)],check=True,capture_output=True)
            headers={'X-Support-Key':pub.read_bytes()[-32:].hex(),'X-Support-Time':str(now),'X-Support-Nonce':nonce,'X-Support-Signature':base64.b64encode(sig.read_bytes()).decode()}
            store=Store(root/'db')
            for method,path,data,stamp in [('GET','/support/v1/messages',payload,now),('POST','/support/v1/replies',payload,now),('POST','/support/v1/messages',b'changed',now),('POST','/support/v1/messages',payload,now+301)]:
                with self.assertRaises(ValueError):authenticate(store,headers,method,path,data,stamp)
            self.assertEqual(hashlib.sha256(pub.read_bytes()[-32:]).hexdigest(),authenticate(store,headers,'POST','/support/v1/messages',payload,now))
            with self.assertRaises(ValueError):authenticate(store,headers,'POST','/support/v1/messages',payload,now)

if __name__=='__main__':unittest.main()
