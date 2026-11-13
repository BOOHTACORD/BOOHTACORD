"""The archived verifier must accept exactly the supported deployment layouts."""
import copy
import unittest

from . import deployment
from .test_deployment import fixture


class ComponentReadbackTests(unittest.TestCase):
    def test_valid_three_component_receipt_and_strict_negative_cases(self):
        run, jobs, data, producer = fixture()
        source = data['delivery']['source_revision']
        ack = data['delivery']['readback']
        ack['sources']['join-sound-processor'] = source
        ack['running_images']['join-sound-processor'] = 'sha256:' + 'a' * 64
        self.assertEqual(deployment.proof(run, jobs, data, producer)['status'], 'PASS')
        for mutation in ('wrong_source', 'missing_image', 'unknown_component', 'invalid_image'):
            invalid = copy.deepcopy(data)
            readback = invalid['delivery']['readback']
            if mutation == 'wrong_source':
                readback['sources']['join-sound-processor'] = 'f' * 40
            elif mutation == 'missing_image':
                del readback['running_images']['join-sound-processor']
            elif mutation == 'unknown_component':
                readback['sources']['unknown-service'] = readback['sources'].pop('join-sound-processor')
                readback['running_images']['unknown-service'] = readback['running_images'].pop('join-sound-processor')
            else:
                readback['running_images']['join-sound-processor'] = 'invalid'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                deployment.proof(run, jobs, invalid, producer)


if __name__ == '__main__':
    unittest.main()
