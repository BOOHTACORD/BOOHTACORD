"""Runner integrity checks, separate from real application acceptance."""
import json
import tempfile
import unittest
import urllib.request
import urllib.error
from pathlib import Path
from unittest.mock import patch
from .integrity import archive_previous, validate_report, validate_device

class RunnerContracts(unittest.TestCase):
    def test_foreign_device_is_rejected_before_platform_lookup(self):
        with patch('subprocess.check_output') as lookup:
            for platform,device in [('android','emulator-5554'),('ios','foreign')]:
                with self.assertRaises(ValueError):validate_device(platform,device)
            lookup.assert_not_called()

    def test_new_attempt_cannot_republish_previous_pass_or_images(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'android';path.mkdir()
            (path/'scenario.json').write_text('{"status":"PASS"}')
            (path/'runtime.json').write_text('{"status":"PASS"}')
            (path/'old.png').write_bytes(b'old')
            archive_previous(path)
            self.assertFalse((path/'scenario.json').exists())
            self.assertEqual(list(path.glob('*.png')),[])

    def test_loopback_bridge_rejects_wrong_nonce_and_unknown_action_without_OS_dispatch(self):
        from .os_control import AndroidLifecycleBridge
        with patch('tools.qa.dm_composer.os_control.validate_device'), patch('tools.qa.dm_composer.os_control.subprocess.run') as dispatch:
            with AndroidLifecycleBridge('emulator-5556') as bridge:
                for path,key in [('/background-resume','wrong'),('/unassigned-action',bridge.key)]:
                    request=urllib.request.Request('http://127.0.0.1:4944'+path,data=b'',headers={'X-QA-Control':key},method='POST')
                    with self.assertRaises(urllib.error.HTTPError) as error:
                        urllib.request.urlopen(request,timeout=2)
                    self.assertEqual(error.exception.code,403)
                dispatch.assert_not_called()
                self.assertEqual(bridge.count,0)

    def test_partial_or_missing_scenario_rows_cannot_be_success(self):
        valid={'status':'PASS','checks':{'flow':'PASS','ACL':'PASS'}}
        for value in [{'status':'PASS','checks':{}},{'status':'PASS','checks':{'flow':'NOT_RUN'}},{'status':'FAIL','checks':{'flow':'PASS'}}]:
            with self.assertRaises(ValueError):validate_report(value,['flow','ACL'])
        self.assertEqual(validate_report(valid,['flow','ACL']),valid)

if __name__=='__main__':unittest.main()
