"""Acceptance receipt/loopback controls; these unit fixtures are not app acceptance."""
import json,tempfile,threading,time,unittest,urllib.request,urllib.error
from pathlib import Path
from .run import REQUIRED,validated
from .native import REQUIRED_NATIVE,validated_scenario,validated_supplement
from .bridge import RosterBridge
class RunnerTests(unittest.TestCase):
 def web(self):return{'status':'PASS','checks':{k:'PASS'for k in REQUIRED},'actual_api':True,'actual_sfu':True,'mocks':False,'observer_counters':{'max_active':1}}
 def test_web_missing_scenario_rejected(self):
  d=self.web();del d['checks'][REQUIRED[0]]
  with self.assertRaises(RuntimeError):validated(d)
 def test_web_transport_or_duplicate_watcher_rejected(self):
  for k,v in [('actual_sfu',False),('mocks',True)]:
   d=self.web();d[k]=v
   with self.assertRaises(RuntimeError):validated(d)
  d=self.web();d['observer_counters']['max_active']=2
  with self.assertRaises(RuntimeError):validated(d)
 def test_android_incomplete_lifecycle_rejected(self):
  d={'status':'PASS','checks':{k:'PASS'for k in REQUIRED_NATIVE}}
  with self.assertRaises(RuntimeError):validated_scenario(d,'android')
 def test_ios_nonmedia_cannot_become_overall_pass(self):
  d={'status':'PASS','checks':{k:'PASS'for k in REQUIRED_NATIVE}};self.assertEqual(validated_scenario(d,'ios')['status'],'PARTIAL')
 def test_supplement_requires_each_completed_actual_phase(self):
  value={'status':'PASS','actual_api':True,'actual_sfu':True,'mocks':False,'checks':{k:'PASS'for k in ('background_foreground','listener_framebuffer','cleanup')}}
  self.assertEqual(validated_supplement(value)['status'],'PASS')
  for key in value['checks']:
   incomplete={**value,'checks':{**value['checks'],key:'NOT_RUN'}}
   with self.assertRaises(RuntimeError):validated_supplement(incomplete)
 def test_supplement_rejects_false_transport_and_partial_receipt(self):
  value={'status':'PASS','actual_api':True,'actual_sfu':True,'mocks':False,'checks':{k:'PASS'for k in ('background_foreground','listener_framebuffer','cleanup')}}
  for key,v in [('actual_api',False),('actual_sfu',False),('mocks',True),('status','PARTIAL')]:
   with self.assertRaises(RuntimeError):validated_supplement({**value,key:v})
 def test_loopback_auth_and_unsupported_action(self):
  with tempfile.TemporaryDirectory()as directory, RosterBridge(directory,'unit-secret','qa272-'+'a'*16,'android',port=0,timeout=.2)as bridge:
   url='http://127.0.0.1:'+str(bridge.server.server_port)+'/roster'
   for secret,action,want in [('wrong','peer_leave',403),('unit-secret','foreign_delete',502)]:
    req=urllib.request.Request(url,data=json.dumps({'action':action}).encode(),headers={'X-QA-Control':secret},method='POST')
    with self.assertRaises(urllib.error.HTTPError)as e:urllib.request.urlopen(req,timeout=2)
    self.assertEqual(e.exception.code,want);self.assertFalse((Path(directory)/'control-command.json').exists())
 def test_string_nonce_and_untrusted_ack_rejected(self):
  for change in [{'request':'old'},{'action':'peer_join'},{'actual_control':False},{'status':'FAIL'}]:
   with tempfile.TemporaryDirectory()as directory:
    bridge=RosterBridge(directory,'unit-secret','qa272-'+'a'*16,'android',port=0,timeout=.2)
    def writer():
     p=Path(directory)/'control-command.json'
     while not p.exists():time.sleep(.005)
     d=json.loads(p.read_text());self.assertIsInstance(d['request'],str);self.assertEqual(len(d['request']),32);v={**d,'status':'PASS','actual_control':True,**change};q=Path(directory)/'control-ack.pending';q.write_text(json.dumps(v));q.replace(Path(directory)/'control-ack.json')
    t=threading.Thread(target=writer);t.start()
    with self.assertRaises((RuntimeError,TimeoutError)):bridge.control('peer_leave')
    t.join(timeout=1);bridge.server.server_close()
if __name__=='__main__':unittest.main()
