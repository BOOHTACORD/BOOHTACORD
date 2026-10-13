import unittest
from . import run
class CopyPlanTests(unittest.TestCase):
 def test_all_qa_sources_have_unique_bounded_two_column_destinations(self):
  plan=run.qa_copy_plan()
  self.assertGreater(len(plan),5)
  self.assertEqual(len({destination for _,destination in plan}),len(plan))
  for original,destination in plan:
   self.assertTrue(run.Path(__file__).with_name(original).is_file())
   self.assertTrue(destination.startswith(('integration_test/qa98325_','test/qa98325_')))
   self.assertNotIn('..',destination)

 def test_current_entry_adapts_only_legacy_mode_call_in_older_marked_source(self):
  import tempfile
  with tempfile.TemporaryDirectory() as d:
   flutter=run.Path(d)/'flutter';(flutter/'integration_test').mkdir(parents=True)
   entry=flutter/'integration_test/qa98325_native_app.dart';source=run.Path(__file__).with_name('native_app.dart').read_text();entry.write_text(source)
   run.adapt_legacy_mode_entry(flutter)
   self.assertNotIn("profile/content_mode.dart",entry.read_text())
   self.assertNotIn('contentMode:stageContentMode',entry.read_text())
   self.assertIn('Legacy baseline has no independent mode',entry.read_text())
