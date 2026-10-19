import json
from pathlib import Path
import tempfile
import unittest
from .metadata import prepare, check_machine

INSTALLER='1a449444c387b1966244ae4d4f8c696479add0b2'
FRAMEWORK='abaf9c523780a608bd46686fd5e53740a07077f8'


class FlutterMetadataTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory();self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name).resolve()
        self.toolcache=self.root/'toolcache';self.temp=self.root/'runner-temp';self.temp.mkdir()
        self.source={'schema_version':1,'installer_repository':'subosito/flutter-action','installer_revision':INSTALLER,
                     'flutter':'3.47.7','framework_revision':FRAMEWORK}
        data={'tools/toolchains.json':{'node':'24.18.0','go':'1.26.4','flutter':'3.47.7','dart':'3.13.5'},
              'tools/ci/flutter_setup/source.json':self.source,
              'tools/verify/action_pins/pins.json':{'schema_version':1,'actions':[{'action':'subosito/flutter-action','commit':INSTALLER}]}}
        for name,value in data.items():
            path=self.root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(value))
        (self.root/'.node-version').write_text('24.18.0')
        (self.root/'backend').mkdir();(self.root/'backend/go.mod').write_text('go 1.26.0\ntoolchain go1.26.4\n')

    def metadata(self,system='Windows',arch='X64',version='3.47.7',channel='stable'):
        return prepare(self.root,self.toolcache,self.temp,system,arch,version,channel)

    def test_sdk_cache_is_public_scoped_and_pub_cache_is_always_new_private_work(self):
        a,b=self.metadata(),self.metadata()
        self.assertEqual(a['cache_key'],b['cache_key'])
        self.assertEqual(a['cache_path'],b['cache_path'])
        self.assertNotEqual(a['pub_cache'],b['pub_cache'])
        self.assertTrue(Path(a['pub_cache']).is_relative_to(self.temp))
        self.assertTrue(Path(a['cache_path']).is_relative_to(self.toolcache))
        self.assertFalse(Path(a['flutter_root']).exists(),'an empty SDK directory must not suppress installation')
        self.assertIn(FRAMEWORK,a['cache_key'])
        self.assertNotEqual(a['cache_key'],self.metadata('Linux')['cache_key'])
        self.assertNotEqual(a['cache_key'],self.metadata('Windows','ARM64')['cache_key'])

    def test_installer_revision_and_sdk_inputs_cannot_drift_or_override_source(self):
        for version,channel in [('stable','stable'),('3.47.7','beta'),('9.0.0','stable')]:
            with self.assertRaises(ValueError): self.metadata(version=version,channel=channel)
        self.source['installer_revision']='b'*40
        (self.root/'tools/ci/flutter_setup/source.json').write_text(json.dumps(self.source))
        with self.assertRaises(ValueError): self.metadata()

    def test_cached_machine_must_match_framework_revision_flutter_and_dart(self):
        expected=self.metadata()
        machine={'frameworkVersion':'3.47.7','frameworkRevision':FRAMEWORK,'dartSdkVersion':'3.13.5 (stable)'}
        check_machine(machine,expected)
        for key,value in [('frameworkVersion','3.47.8'),('frameworkRevision','f'*40),('dartSdkVersion','3.13.4')]:
            changed=dict(machine);changed[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError): check_machine(changed,expected)

    def test_unknown_os_or_architecture_is_not_a_shared_cache_fallback(self):
        for system,arch in [('unknown','X64'),('Linux','unknown')]:
            with self.assertRaises(ValueError): self.metadata(system,arch)
