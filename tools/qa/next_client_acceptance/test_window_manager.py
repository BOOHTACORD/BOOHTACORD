import subprocess
import unittest
from types import SimpleNamespace
from unittest.mock import Mock

from .window_manager import has_window_manager, wait_for_window_manager


class WindowManagerTests(unittest.TestCase):
    def test_accepts_only_a_nonzero_ewmh_window_manager_id(self):
        run = Mock(side_effect=[
            SimpleNamespace(returncode=0, stdout='_NET_SUPPORTING_WM_CHECK: not found\\n'),
            SimpleNamespace(returncode=0, stdout='_NET_SUPPORTING_WM_CHECK(WINDOW): window id # 0x0\\n'),
            SimpleNamespace(returncode=0, stdout='_NET_SUPPORTING_WM_CHECK(WINDOW): window id # 0x400001\\n'),
        ])

        self.assertFalse(has_window_manager(run))
        self.assertFalse(has_window_manager(run))
        self.assertTrue(has_window_manager(run))
        self.assertEqual(run.call_count, 3)
        self.assertEqual(run.call_args.args[0], ['xprop', '-root', '_NET_SUPPORTING_WM_CHECK'])
        self.assertEqual(run.call_args.kwargs['stdout'], subprocess.PIPE)
        self.assertEqual(run.call_args.kwargs['stderr'], subprocess.DEVNULL)

    def test_retries_until_the_window_manager_is_ready(self):
        observations = iter([False, False, True])
        now = [0.0]
        sleep = Mock(side_effect=lambda seconds: now.__setitem__(0, now[0] + seconds))

        wait_for_window_manager(
            timeout=1.0,
            interval=0.25,
            probe=lambda: next(observations),
            sleep=sleep,
            monotonic=lambda: now[0],
        )

        self.assertEqual(sleep.call_count, 2)
        self.assertAlmostEqual(now[0], 0.5)

    def test_fails_closed_when_no_window_manager_becomes_ready(self):
        now = [0.0]
        sleep = Mock(side_effect=lambda seconds: now.__setitem__(0, now[0] + seconds))

        with self.assertRaisesRegex(TimeoutError, 'window manager did not become ready'):
            wait_for_window_manager(
                timeout=0.5,
                interval=0.25,
                probe=lambda: False,
                sleep=sleep,
                monotonic=lambda: now[0],
            )

        self.assertAlmostEqual(now[0], 0.5)
        self.assertEqual(sleep.call_count, 2)


if __name__ == '__main__':
    unittest.main()
