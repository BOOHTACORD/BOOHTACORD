import base64
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from .keys import create
from .sign import sign
from .verify import verify
from .promote import promote

OPENSSL=os.environ.get('BOOHTACORD_TEST_OPENSSL') or ('/opt/homebrew/opt/openssl@3/bin/openssl' if Path('/opt/homebrew/opt/openssl@3/bin/openssl').is_file() else shutil.which('openssl'))

class PublisherTest(unittest.TestCase):
    def setUp(self):
        self.directory=tempfile.TemporaryDirectory();self.addCleanup(self.directory.cleanup)
        self.root=Path(self.directory.name);self.private=self.root/'publisher.pem';self.public=self.root/'publisher.pub'
        create(self.private,self.public,OPENSSL)
        self.package=self.root/'boohtacord-1.0.43-full.nupkg';self.package.write_bytes(b'local package fixture')
        self.payload=dict(schema_version=1,application_family='boohtacord',package_id='boohtacord_desktop',release_id='windows-direct-stable-r57',release_order=57,version='1.0.43',native_build='78',platform='windows',arch='x64',distribution='direct',channel='stable',package_type='velopack_nupkg',download_url='https://github.com/BOOHTACORD/BOOHTACORD/releases/download/windows-v1.0.43/boohtacord-1.0.43-full.nupkg',min_os_version='10.0',min_api_version=1,min_updater_version=1,expires_at='2028-10-14T00:00:00Z')
        self.envelope=sign(self.payload,self.package,self.private,self.public,OPENSSL)

    def test_trusted_roundtrip_and_tampering(self):
        payload=verify(self.envelope,self.package,self.public,OPENSSL)
        self.assertEqual(payload['native_build'],'78')
        changed=dict(self.envelope);changed['payload']=base64.b64encode(json.dumps(dict(payload,version='9.0.0')).encode()).decode()
        with self.assertRaisesRegex(ValueError,'signature'):verify(changed,self.package,self.public,OPENSSL)
        self.package.write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError,'size'):verify(self.envelope,self.package,self.public,OPENSSL)

    def test_promotion_requires_uploaded_matching_published_asset_and_cas(self):
        payload=verify(self.envelope,self.package,self.public,OPENSSL)
        release=dict(draft=False,prerelease=False,published_at='2026-10-15T00:00:00Z',tag_name='windows-v1.0.43',html_url='https://github.com/BOOHTACORD/BOOHTACORD/releases/tag/windows-v1.0.43',assets=[dict(browser_download_url=payload['download_url'],state='uploaded',size=payload['size'],digest='sha256:'+payload['sha256'])])
        catalog=self.root/'catalog.json'
        catalog.write_text(json.dumps(dict(schema_version=1,catalog_revision=1,application_family='boohtacord',entries=[dict(platform='windows',distribution='direct',channel='stable',arch='x64',state='unconfigured',target=None)])))
        invalid=dict(release,draft=True)
        with self.assertRaises(ValueError):promote(catalog,1,invalid,self.envelope,self.package,self.public,arch='x64',openssl=OPENSSL)
        self.assertEqual(json.loads(catalog.read_text())['catalog_revision'],1)
        promoted=promote(catalog,1,release,self.envelope,self.package,self.public,arch='x64',openssl=OPENSSL)
        self.assertEqual(promoted['catalog_revision'],2)
        self.assertEqual(promoted['entries'][0]['target']['install_artifact'],self.envelope)
        with self.assertRaisesRegex(ValueError,'revision'):promote(catalog,1,release,self.envelope,self.package,self.public,arch='x64',openssl=OPENSSL)

    def test_existing_publisher_key_is_never_replaced(self):
        with self.assertRaises(ValueError):create(self.private,self.public,OPENSSL)
        self.assertEqual(self.private.stat().st_mode & 0o777,0o600)
