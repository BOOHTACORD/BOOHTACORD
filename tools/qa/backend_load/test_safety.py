import unittest

from tools.qa.backend_load.safety import validate_run


class ValidateRunTests(unittest.TestCase):
    def test_requires_isolated_deployment_confirmation(self):
        with self.assertRaises(ValueError):
            validate_run('http://127.0.0.1:4820', 1, 1, '')

    def test_rejects_public_and_production_targets(self):
        for target in ('https://8.8.8.8', 'https://boohtacord.ru', 'https://example.com',
                       'http://169.254.10.2', 'http://192.0.2.10'):
            with self.subTest(target=target), self.assertRaises(ValueError):
                validate_run(target, 1, 1, 'ISOLATED_TEST_DEPLOYMENT')

    def test_accepts_confirmed_loopback_target(self):
        validate_run('http://127.0.0.1:4820', 4, 4, 'ISOLATED_TEST_DEPLOYMENT')

    def test_enforces_synthetic_account_and_profile_bounds(self):
        for vus, accounts in ((2, 1), (101, 101), (0, 1)):
            with self.subTest(vus=vus, accounts=accounts), self.assertRaises(ValueError):
                validate_run('http://localhost:4820', vus, accounts,
                             'ISOLATED_TEST_DEPLOYMENT')


if __name__ == '__main__':
    unittest.main()
