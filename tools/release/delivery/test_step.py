"""Metadata operations have fixed profiles; input cannot become a shell command."""
import sys
import unittest
from unittest.mock import patch
from . import step
from .commands import ExecutionFailed


class BoundedStepTests(unittest.TestCase):
    def test_only_fixed_operations_and_selected_interpreter_can_execute(self):
        for name,(module,args,limit) in step.OPERATIONS.items():
            with patch.object(sys,'argv',['step',name]),patch.object(step,'execute') as execute:
                step.main()
            execute.assert_called_once_with([sys.executable,'-m','tools.release.delivery.'+module,*args],limit)

    def test_shell_syntax_or_unknown_operation_never_executes(self):
        for name in ('unknown','producer;echo private-canary','../consumer'):
            with patch.object(sys,'argv',['step',name]),patch.object(step,'execute') as execute,self.assertRaises(SystemExit): step.main()
            execute.assert_not_called()

    def test_timeout_remains_failure_with_no_arbitrary_command_output(self):
        with patch.object(sys,'argv',['step','download']),patch.object(step,'execute',side_effect=ExecutionFailed('timeout')):
            with self.assertRaises(SystemExit) as result: step.main()
        self.assertIn('download (timeout)',str(result.exception)); self.assertNotIn('private',str(result.exception))
