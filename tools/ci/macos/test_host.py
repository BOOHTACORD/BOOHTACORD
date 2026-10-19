import unittest
from .host import validate


class MacHostTests(unittest.TestCase):
    def test_exact_reviewed_xcode_and_real_runner_architecture(self):
        validate(dict(system='Darwin',architecture='arm64',os_version='26.6.2',xcode_version='26.6',xcode_build='17F113',macos_sdk='26.5'),'arm64')

    def test_missing_wrong_arch_or_different_xcode_is_not_green(self):
        row=dict(system='Darwin',architecture='arm64',os_version='26.6.2',xcode_version='26.6',xcode_build='17F113',macos_sdk='26.5')
        for key,value in [('system','Linux'),('architecture','x86_64'),('xcode_version','27.1'),('xcode_build','other'),('macos_sdk','27.0')]:
            with self.subTest(key=key),self.assertRaises(ValueError):validate(dict(row,**{key:value}),'arm64')
