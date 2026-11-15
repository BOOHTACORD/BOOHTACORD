import unittest
from unittest.mock import patch
from . import compiler



class CompilerTests(unittest.TestCase):
    def test_existing_exact_compiler_never_changes_the_user_toolchain(self):
        with patch.object(compiler.subprocess, 'check_output', return_value='rustc 1.97.1 exact'), \
             patch.object(compiler.subprocess, 'run') as install:
            _, version = compiler.select()
            assert version.startswith('rustc 1.97.1 ')
            install.assert_not_called()


    def test_other_default_selects_the_exact_compiler_only_in_child_environment(self):
        with patch.object(compiler.subprocess, 'check_output', side_effect=['rustc 1.96.0 old', 'rustc 1.97.1 exact']), \
             patch.object(compiler.subprocess, 'run') as install:
            env, _ = compiler.select()
            install.assert_called_once_with(['rustup', 'toolchain', 'install', '1.97.1', '--profile', 'minimal', '--no-self-update'], check=True)
            assert env['RUSTUP_TOOLCHAIN'] == '1.97.1'
