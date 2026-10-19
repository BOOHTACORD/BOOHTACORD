"""Stale source/recipe, wrong ABI, skipped tests or incomplete SDK matrix never pass."""
import copy
import unittest
from .contract import inputs,validate_slice,validate_matrix


def fixture(arch):
    expected=inputs();return dict(expected,architecture=arch,gn_args=expected['gn_base']+' target_cpu="'+arch+'"',
        builder_revision='a'*40,run_id='101',run_attempt='1',framework_binary_sha256='b'*64,archive_sha256='c'*64,native_test_report_sha256='d'*64,owned_workspace_removed=True,
        native_route_tests='PASS',native_test_count=2,physical_playback_smoke='NOT_RUN',
        toolchain=dict(xcode_version='26.6',xcode_build='17F113',macos_sdk='26.5'),binary_architectures=['arm64' if arch=='arm64' else 'x86_64'])


class SDKContractTests(unittest.TestCase):
    def test_complete_matching_native_matrix(self):validate_matrix([fixture('arm64'),fixture('x64')],'a'*40,'101','1')

    def test_wrong_arch_stale_recipe_source_execution_or_partial_matrix_fails(self):
        row=fixture('arm64')
        for key,value in [('architecture','x64'),('recipe_sha256','f'*64),('source_revision','f'*40),
                          ('builder_revision','f'*40),('run_id','102'),('native_route_tests','NOT_RUN'),
                          ('binary_architectures',['x86_64']),('native_test_count',0),('owned_workspace_removed',False)]:
            changed=copy.deepcopy(row);changed[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_slice(changed,'arm64','a'*40,'101','1')
        for rows in [[],[fixture('arm64')],[fixture('arm64'),fixture('arm64')]]:
            with self.assertRaises(ValueError):validate_matrix(rows,'a'*40,'101','1')
