import unittest

from .fingerprint import run_frames


class FingerprintTest(unittest.TestCase):
    def test_repeatable_non_silent_synthetic_output(self):
        def half(_state, source, output, count):
            for i in range(count):
                output[i] = source[i] / 2
            return 0
        first = run_frames(half, None, 4)
        self.assertEqual(first, run_frames(half, None, 4))
        self.assertNotEqual(first, run_frames(half, None, 3))

    def test_nonfinite_and_error_fail_closed(self):
        def bad(_state, _source, output, _count):
            output[0] = float('nan')
            return 0
        with self.assertRaises(ValueError):
            run_frames(bad, None, 1)
        with self.assertRaises(ValueError):
            run_frames(lambda *_args: 1, None, 1)
        with self.assertRaises(ValueError):
            run_frames(lambda *_args: 0, None, 1)


if __name__ == '__main__':
    unittest.main()
