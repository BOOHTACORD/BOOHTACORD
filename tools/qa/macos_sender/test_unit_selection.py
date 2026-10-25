"""Every copied QA regression must run in both native build paths."""
import ast
from pathlib import Path
import unittest
from .run import qa_copy_plan


class SelectionTests(unittest.TestCase):
    def test_both_native_builds_execute_every_copied_test(self):
        expected = {destination for _, destination in qa_copy_plan() if destination.startswith('test/')}
        for filename in ('run.py', 'candidate.py'):
            tree = ast.parse(Path(__file__).with_name(filename).read_text())
            lists = [node for node in ast.walk(tree) if isinstance(node, ast.List)
                     and len(node.elts) > 1 and all(isinstance(x, ast.Constant) for x in node.elts[:2])
                     and [x.value for x in node.elts[:2]] == ['flutter', 'test']]
            self.assertEqual(1, len(lists))
            selected = {x.value for x in lists[0].elts if isinstance(x, ast.Constant)}
            with self.subTest(filename=filename): self.assertLessEqual(expected, selected)
