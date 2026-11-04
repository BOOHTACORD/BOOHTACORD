import unittest

from tools.build.egress_clock_fix.patch import apply_patch


class EgressClockFixTests(unittest.TestCase):
    def test_preserves_the_packet_receipt_timestamp(self):
        source = b'if ready {\n\tw.buffer.Push(pkt)\n}\n'
        expected = b'if ready {\n\tw.buffer.PushAt(pkt, receivedAt)\n}\n'
        self.assertEqual(apply_patch(source), expected)

    def test_rejects_missing_or_ambiguous_upstream_source(self):
        for source in (b'other', b'w.buffer.Push(pkt)\nw.buffer.Push(pkt)'):
            with self.subTest(source=source), self.assertRaises(ValueError):
                apply_patch(source)


if __name__ == '__main__':
    unittest.main()
