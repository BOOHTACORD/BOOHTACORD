import unittest
from unittest.mock import patch
from .lint import command, main


class WorkflowLintTests(unittest.TestCase):
    def test_go_resolves_full_reviewed_source_not_a_mutable_tag(self):
        args = command({'actionlint_source_revision': 'a' * 40})
        self.assertIn('github.com/rhysd/actionlint/cmd/actionlint@' + 'a' * 40, args)
        self.assertEqual(args[-2:], ['-shellcheck=', '-pyflakes='])

    def test_missing_or_mutable_source_is_not_linted_as_pass(self):
        for value in [None, 'v1.7.11', 'main', 'a' * 39]:
            with self.assertRaises(ValueError):
                command({'actionlint_source_revision': value})

    def test_lint_requires_the_approved_actual_go_toolchain(self):
        with patch('tools.verify.action_pins.lint.output', return_value='go version go1.26.4 darwin/arm64'):
            with patch('tools.verify.action_pins.lint.subprocess.run') as run:
                main()
                run.assert_called_once()
        with patch('tools.verify.action_pins.lint.output', return_value='go version go1.26.0 linux/amd64'):
            with patch('tools.verify.action_pins.lint.subprocess.run') as run:
                with self.assertRaises(RuntimeError): main()
                run.assert_not_called()
