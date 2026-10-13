import json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from . import observe
class ObserveTests(unittest.TestCase):
 def test_foreign_preflight_cannot_leave_previous_PASS(self):
  with tempfile.TemporaryDirectory() as temporary:
   out=Path(temporary);(out/'startup-0.json').write_text('{"status":"PASS"}')
   with patch.object(observe,'OUT',out),patch('sys.argv',['observe','--work',str(out/'foreign'),'--mode','startup','--index','0']):
    with self.assertRaises(ValueError):observe.main()
   self.assertEqual(json.loads((out/'startup-0.json').read_text())['status'],'FAIL')
   self.assertEqual(len(list((out/'previous').rglob('startup-0.json'))),1)
