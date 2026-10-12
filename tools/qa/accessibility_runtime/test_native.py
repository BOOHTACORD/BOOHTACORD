import unittest
from .native import validated_scenario, REQUIRED_NATIVE
from .run import validated_web, REQUIRED_WEB, AXE_WEB, validated_build_provenance, validated_active_geometry

class AcceptanceReceipt(unittest.TestCase):
 def scenario(self,platform='android'):
  return {'status':'PASS','checks':{**{k:'PASS' for k in REQUIRED_NATIVE},'native_stream_setup_names_2x':'PASS' if platform=='android' else 'NOT_RUN'}}
 def test_stale_or_empty_pass_cannot_complete_acceptance(self):
  for d in ({'status':'PASS','checks':{}},{'status':'PASS'},{'status':'RUNNING','checks':self.scenario()['checks']}):
   with self.assertRaises(RuntimeError):validated_scenario(d,'android')
 def test_missing_failed_or_not_run_required_row_rejected(self):
  for value in ('FAIL','NOT_RUN',None):
   d=self.scenario();d['checks'][REQUIRED_NATIVE[0]]=value
   with self.assertRaises(RuntimeError):validated_scenario(d,'android')
 def test_android_stream_not_run_cannot_pass(self):
  d=self.scenario();d['checks']['native_stream_setup_names_2x']='NOT_RUN'
  with self.assertRaises(RuntimeError):validated_scenario(d,'android')
 def test_ios_missing_media_is_honest_partial(self):
  d=self.scenario('ios');self.assertEqual(validated_scenario(d,'ios')['status'],'PARTIAL')
 def test_completed_android_is_scoped_pass(self):self.assertEqual(validated_scenario(self.scenario(),'android')['status'],'PASS')

class ActiveDockReceipt(unittest.TestCase):
 def scenario(self):
  names=[f'{kind}-{width}-{scale}x' for width in (393,320) for scale in (1,2) for kind in ('voice-TEXT','voice-DM','members','search','search-scope')]
  return {'status':'PASS','actual_api':True,'actual_sfu':True,'mocks':False,'rows':[{'name':name,'status':'PASS'} for name in names]}
 def test_all_twenty_required_actual_rows_complete(self):self.assertEqual(validated_active_geometry(self.scenario())['status'],'PASS')
 def test_scope_clipping_row_is_required(self):
  d=self.scenario();d['rows']=[r for r in d['rows'] if r['name']!='search-scope-320-2x']
  with self.assertRaises(RuntimeError):validated_active_geometry(d)
 def test_missing_failed_duplicate_and_mocked_rows_rejected(self):
  d=self.scenario();d['rows'].pop()
  with self.assertRaises(RuntimeError):validated_active_geometry(d)
  d=self.scenario();d['rows'][0]['status']='FAIL'
  with self.assertRaises(RuntimeError):validated_active_geometry(d)
  d=self.scenario();d['rows'][0]['name']=d['rows'][1]['name']
  with self.assertRaises(RuntimeError):validated_active_geometry(d)
  d=self.scenario();d['actual_sfu']=False
  with self.assertRaises(RuntimeError):validated_active_geometry(d)

class BuildProvenance(unittest.TestCase):
 def test_copied_binary_requires_exact_root_build_link(self):
  source={'status':'PASS','source_stable_during_unit_and_build':True,'built_dist_manifest_sha256':'binary','web_src_manifest_sha256':'source'}
  self.assertEqual(validated_build_provenance(source,'binary')['web_src_manifest_sha256'],'source')
  for delta in ({'built_dist_manifest_sha256':'other'},{'status':'FAIL'},{'source_stable_during_unit_and_build':False},{'web_src_manifest_sha256':None}):
   with self.assertRaises(RuntimeError):validated_build_provenance(dict(source,**delta),'binary')

class BrowserReceipt(unittest.TestCase):
 def scenario(self):return {'status':'PARTIAL','actual_api':True,'actual_sfu':True,'mocks':False,'checks':{**{k:'PASS' for k in REQUIRED_WEB},**{'axe_'+k:'PASS' for k in AXE_WEB}}}
 def test_complete_automated_scope_stays_partial_without_readers(self):self.assertEqual(validated_web(self.scenario())['status'],'PARTIAL')
 def test_missing_or_failed_required_axe_rejected(self):
  for value in ('FAIL','NOT_RUN',None):
   d=self.scenario();d['checks']['axe_chat']=value
   with self.assertRaises(RuntimeError):validated_web(d)
 def test_missing_real_transport_rejected(self):
  for key,value in [('actual_api',False),('actual_sfu',False),('mocks',True)]:
   d=self.scenario();d[key]=value
   with self.assertRaises(RuntimeError):validated_web(d)

if __name__=='__main__':unittest.main()
