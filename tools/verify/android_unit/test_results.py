"""Discovery is per class; a different passing class cannot cover a missing one."""
from pathlib import Path
import tempfile
import unittest
from .results import validate


class JUnitTests(unittest.TestCase):
    def check(self, xml, expected=None):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'TEST-example.xml'
            path.write_text(xml)
            return validate(Path(directory), expected or {'one.Class': 1})

    def test_pass_requires_actual_cases_in_every_class(self):
        self.assertEqual({'one.Class': 1}, self.check('<testsuite><testcase classname="one.Class" name="a"/></testsuite>'))

    def test_empty_missing_class_duplicate_skipped_failed_and_lying_totals_fail(self):
        for xml in (
            '<testsuite tests="100"/>',
            '<testsuite><testcase classname="another.Class" name="a"/></testsuite>',
            '<testsuite><testcase classname="one.Class" name="a"/><testcase classname="one.Class" name="a"/></testsuite>',
            '<testsuite><testcase classname="one.Class" name="a"><skipped/></testcase></testsuite>',
            '<testsuite><testcase classname="one.Class" name="a"><failure/></testcase></testsuite>',
            '<testsuite><testcase classname="one.Class" name="a"><error/></testcase></testsuite>',
            '<testsuite failures="1"><testcase classname="one.Class" name="a"/></testsuite>',
        ):
            with self.subTest(xml=xml), self.assertRaises(ValueError): self.check(xml)
        with self.assertRaises(ValueError):
            self.check('<testsuite><testcase classname="one.Class" name="a"/></testsuite>', {'one.Class': 1, 'two.Class': 1})

    def test_missing_directory_and_no_xml_cannot_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            for path in (Path(directory), Path(directory) / 'missing'):
                with self.assertRaises(ValueError): validate(path, {'one.Class': 1})
