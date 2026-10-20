"""Receipt integrity checks; these do not replace real media acceptance."""
import json
import tempfile
import unittest
from pathlib import Path
from .bridge import PublisherBridge
from urllib.request import Request, urlopen
from urllib.error import HTTPError
import subprocess
import secrets
import threading
import time
from unittest.mock import patch
from .native import archive_previous, validated_outcome, REQUIRED_CHECKS, source_manifest, verify_owned_device


class ReceiptIntegrity(unittest.TestCase):
    def test_previous_pass_and_screenshots_are_archived_before_new_attempt(self):
        with tempfile.TemporaryDirectory() as tmp:
            output=Path(tmp)/'android';output.mkdir()
            (output/'scenario.json').write_text('{"status":"PASS"}')
            (output/'runtime.json').write_text('{"status":"PASS"}')
            (output/'old.png').write_bytes(b'old capture')
            archive_previous(output)
            self.assertFalse((output/'scenario.json').exists())
            self.assertEqual(list(output.glob('*.png')),[])
            self.assertEqual(len(list((Path(tmp)/'previous-attempts').rglob('scenario.json'))),1)
            with self.assertRaises(FileNotFoundError):validated_outcome(output/'scenario.json')

    def test_pass_requires_every_observed_required_check(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'scenario.json'
            checks={key:'PASS' for key in REQUIRED_CHECKS}
            for failure in ('NOT_RUN','BLOCKED','FAIL'):
                checks[REQUIRED_CHECKS[-1]]=failure
                path.write_text(json.dumps({'status':'PASS','checks':checks}))
                with self.assertRaises(RuntimeError):validated_outcome(path)
            checks[REQUIRED_CHECKS[-1]]='PASS'
            path.write_text(json.dumps({'status':'PASS','checks':checks}))
            self.assertEqual(validated_outcome(path)['status'],'PASS')
            path.write_text(json.dumps({'status':'FAIL','checks':checks}))
            with self.assertRaises(RuntimeError):validated_outcome(path)

    def test_whole_lib_manifest_includes_nested_source_build_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            lib=Path(tmp)/'lib';(lib/'screen/build').mkdir(parents=True)
            path=lib/'screen/build/handler.dart';path.write_text('candidate one')
            before,count=source_manifest(lib);self.assertEqual(count,1)
            path.write_text('candidate two')
            self.assertNotEqual(before,source_manifest(lib)[0])


class DeviceOwnership(unittest.TestCase):
    def test_foreign_serial_or_uuid_is_rejected_before_device_lookup(self):
        with patch('tools.qa.mini_player.native.subprocess.check_output') as lookup:
            for platform,device in [('android','emulator-5554'),('ios','foreign')]:
                with self.assertRaises(ValueError):verify_owned_device(platform,device)
            lookup.assert_not_called()

    def test_assigned_serial_with_wrong_avd_is_rejected(self):
        with patch('tools.qa.mini_player.native.subprocess.check_output',return_value='foreign-avd\nOK\n'):
            with self.assertRaises(ValueError):verify_owned_device('android','emulator-5558')

    def test_assigned_uuid_with_wrong_name_is_rejected(self):
        devices={'devices':{'runtime':[{'udid':'57E6A791-8975-4C84-82E6-47321F22C9B8','name':'foreign'}]}}
        with patch('tools.qa.mini_player.native.subprocess.check_output',return_value=json.dumps(devices)):
            with self.assertRaises(ValueError):verify_owned_device('ios','57E6A791-8975-4C84-82E6-47321F22C9B8')


class BridgeIntegrity(unittest.TestCase):
    def test_command_string_nonce_survives_actual_node_json_round_trip(self):
        command={'action':'remove','request':secrets.token_hex(16)}
        result=subprocess.check_output(['node','-e',"let data='';process.stdin.on('data',x=>data+=x);process.stdin.on('end',()=>process.stdout.write(JSON.stringify(JSON.parse(data))))"],input=json.dumps(command),text=True)
        self.assertEqual(json.loads(result)['request'],command['request'])
        self.assertIsInstance(json.loads(result)['request'],str)

    def test_unauthorized_request_cannot_create_publisher_command(self):
        with tempfile.TemporaryDirectory() as tmp:
            with PublisherBridge(tmp,'test-owned-secret',port=0) as bridge:
                url='http://127.0.0.1:'+str(bridge.server.server_port)+'/publisher'
                request=Request(url,data=b'{"action":"remove"}',method='POST')
                with self.assertRaises(HTTPError) as failure:urlopen(request)
                self.assertEqual(failure.exception.code,403)
                self.assertFalse((Path(tmp)/'publisher-command.json').exists())

    def test_real_http_rejects_wrong_nonce_missing_ui_flag_failed_status_and_unknown_action(self):
        for mode in ('wrong_nonce','missing_flag','failed_status','unknown_action'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp:
                directory=Path(tmp)
                with PublisherBridge(tmp,'owned-secret',port=0,timeout=.15) as bridge:
                    def publisher():
                        command=directory/'publisher-command.json'
                        for _ in range(100):
                            if command.exists():
                                data=json.loads(command.read_text());ack={'request':data['request'],'status':'PASS','actual_publisher_ui':True}
                                if mode=='wrong_nonce':ack['request']='stale'
                                elif mode=='missing_flag':ack.pop('actual_publisher_ui')
                                elif mode=='failed_status':ack['status']='FAIL'
                                pending=directory/'ack.pending';pending.write_text(json.dumps(ack));pending.replace(directory/'publisher-ack.json');return
                            time.sleep(.005)
                    worker=threading.Thread(target=publisher);worker.start()
                    request=Request('http://127.0.0.1:'+str(bridge.server.server_port)+'/publisher',data=json.dumps({'action':'unknown' if mode=='unknown_action' else 'remove'}).encode(),headers={'X-QA-Control':'owned-secret'},method='POST')
                    with self.assertRaises(HTTPError) as failure:urlopen(request,timeout=2)
                    self.assertEqual(failure.exception.code,502)
                    worker.join(timeout=1)
                    if mode=='unknown_action':self.assertFalse((directory/'publisher-command.json').exists())

    def test_stale_or_failed_ack_is_never_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory=Path(tmp)
            bridge=PublisherBridge(directory,'test-owned-secret',port=0,timeout=.15)
            try:
                (directory/'publisher-ack.json').write_text('{"request":0,"status":"PASS","actual_publisher_ui":true}')
                with patch('tools.qa.mini_player.bridge.time.monotonic', side_effect=[0, 0, .2]), \
                        patch('tools.qa.mini_player.bridge.time.sleep'):
                    with self.assertRaises(TimeoutError):bridge.control('remove')
                def publisher(_duration):
                    current=json.loads((directory/'publisher-command.json').read_text())
                    ack=directory/'ack.pending'
                    ack.write_text(json.dumps({'request':current['request'],'status':'FAIL','actual_publisher_ui':True}))
                    ack.replace(directory/'publisher-ack.json')
                # Inject the owned response after the new command is visible,
                # independent of thread scheduling and host filesystem latency.
                with patch('tools.qa.mini_player.bridge.time.monotonic', side_effect=[0, 0, .01]), \
                        patch('tools.qa.mini_player.bridge.time.sleep', side_effect=publisher):
                    with self.assertRaises(RuntimeError):bridge.control('publish')
            finally:bridge.server.server_close()


if __name__=='__main__':unittest.main()
